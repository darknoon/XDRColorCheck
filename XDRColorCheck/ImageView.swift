//
//  ImageView.swift
//  XDRColorCheck
//
//  Created by Andrew Pouliot on 10/26/20.
//

import SwiftUI
import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import MetalKit

let bgColor = makeGrey(spaceName: CGColorSpace.extendedLinearDisplayP3, value: 1.0)

var imageOptions: [CIImageOption : Any] {
    get {
        var options: [CIImageOption : Any] = [:]
        options[.applyOrientationProperty] = true
        if #available(iOS 14.1, *) {
            // This seems to do nothing :(
            options[.toneMapHDRtoSDR] = false
        }
        return options
    }
}

func loadCIImage(imageData: Data) -> CIImage? {
    return CIImage(data: imageData, options: imageOptions)
}

func loadCIImageWithCGSource(imageData: Data) -> CIImage? {
    guard let src = CGImageSourceCreateWithData(imageData as CFData, [
        kCGImageSourceShouldAllowFloat: true,
    ] as CFDictionary) else { return nil }
    return CIImage(cgImageSource: src, index: 0, options: imageOptions)
}

func loadCIImageWithGainMap(imageData: Data) -> (image: CIImage?, hasGainMap: Bool) {
    guard let src = CGImageSourceCreateWithData(imageData as CFData, [
        kCGImageSourceShouldAllowFloat: true,
    ] as CFDictionary) else { return (nil, false) }
    
    let primaryIndex = CGImageSourceGetPrimaryImageIndex(src)
    
    var gainMap: CIImage? = nil
    
    var gainValue: CGFloat?
    
    var orientation = CGImagePropertyOrientation.up
    if let props = CGImageSourceCopyPropertiesAtIndex(src, primaryIndex, [:] as CFDictionary) as? [CFString : Any] {
        if let exifOrientation = props[kCGImagePropertyOrientation] as? UInt32, let cgOrientation = CGImagePropertyOrientation(rawValue: exifOrientation) {
            orientation = cgOrientation
        }
        
        if let exif = props[kCGImagePropertyExifDictionary] as? [CFString : Any] {
            if let brightnessValue = exif[kCGImagePropertyExifBrightnessValue] as? CGFloat {
                gainValue = brightnessValue
            }
        }
    }
    
    var outputImage = CIImage(cgImageSource: src, index: 0, options: imageOptions)
    
    // Gain map API is new
    if #available(iOS 14.1, *) {
        if let gainMapInfo = CGImageSourceCopyAuxiliaryDataInfoAtIndex(src, primaryIndex, kCGImageAuxiliaryDataTypeHDRGainMap) as? [CFString : Any] {
            
            if let gainDesc = gainMapInfo[kCGImageAuxiliaryDataInfoDataDescription] as? [CFString : Any],
               let bytesPerRow = gainDesc[kCGImagePropertyBytesPerRow] as? Int,
               let width = gainDesc[kCGImagePropertyWidth] as? Int,
               let height = gainDesc[kCGImagePropertyHeight] as? Int,
               let pixFmt = gainDesc[kCGImagePropertyPixelFormat] as? OSType
               {
                let sizeCG = CGSize(width: CGFloat(width), height: CGFloat(height))

                if pixFmt == kCVPixelFormatType_OneComponent8 {
                    let colorSpace: CGColorSpace? = CGColorSpace(name: CGColorSpace.extendedLinearGray)

                    if let gainMapData = gainMapInfo[kCGImageAuxiliaryDataInfoData] as? Data {
                        gainMap = CIImage(bitmapData: gainMapData,
                                            bytesPerRow: bytesPerRow,
                                            size: sizeCG,
                                            format: .L8,
                                            colorSpace: colorSpace)
                        gainMap = gainMap?.oriented(orientation)
                        gainMap = gainMap?.addMul(add: 1.0, mul: gainValue ?? 1.0)
                    }
                }
            }
        }
    }
    
    
    if let gainMap = gainMap {
        let gainMapUp = aspectFitToDestination(image: gainMap, destination: outputImage.extent.size)
        
        let mulFilter = CIFilter.multiplyBlendMode()
        mulFilter.inputImage = gainMapUp
        mulFilter.backgroundImage = outputImage
        if let combinedImage = mulFilter.outputImage {
            outputImage = combinedImage
        }
        
    } else {
        if let props = CGImageSourceCopyPropertiesAtIndex(src, primaryIndex, [:] as CFDictionary) as? [String : Any] {
            if let gainVal = props[(kCGImagePropertyExifGainControl as String)] {
                print("Found gain: \(gainVal)")
            }
        }
    }
    
    // like what the fuck
    // Find a way to use kCGImageDestinationPreserveGainMap??
    
    return (outputImage, gainMap != nil)
}
    
    
    // like what the fuck
    // Find a way to use kCGImageDestinationPreserveGainMap??
    
    return (outputImage, gainMap != nil)
}

extension CIImage {
    func adjustExposure(ev: Float) -> CIImage? {
        let brightFilter = CIFilter.exposureAdjust()
        brightFilter.ev = ev
        brightFilter.inputImage = self
        return brightFilter.outputImage
    }
    
    func addMul(add: CGFloat, mul: CGFloat) -> CIImage? {
        let brightFilter = CIFilter.colorMatrix()
        brightFilter.rVector = CIVector(x: mul, y: 0, z: 0, w: 0)
        brightFilter.gVector = CIVector(x: 0, y: mul, z: 0, w: 0)
        brightFilter.bVector = CIVector(x: 0, y: 0, z: mul, w: 0)
        brightFilter.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        brightFilter.biasVector = CIVector(x: add, y: add, z: add, w: 0)
        brightFilter.inputImage = self
        
        return brightFilter.outputImage
    }

}

func aspectFitToDestination(image: CIImage, destination: CGSize) -> CIImage {
    let scale: CGFloat = min(destination.width / image.extent.width, destination.height / image.extent.height)
    let t = CGAffineTransform(scaleX: scale, y: scale)
    return image.transformed(by: t)
}

struct PlatformImageView : UIViewRepresentable, ImageDataConstructable {
    
    let imageData: Data
    
    func makeUIView(context: Context) -> UIView {
        let iv = UIImageView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        let v = UIView(frame: iv.frame)
        v.backgroundColor = bgColor
        v.addSubview(iv)
        return v
    }
    
    func updateUIView(_ view: UIView, context: Context) {
        let iv = view.subviews[0] as! UIImageView
        iv.contentMode = .scaleAspectFit
        iv.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        iv.image = UIImage(data: imageData)
    }
}


struct PlatformImageViewCI : UIViewRepresentable, ImageDataConstructable {
    let imageData: Data
    
    func makeUIView(context: Context) -> UIView {
        let iv = UIImageView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        let v = UIView(frame: iv.frame)
        v.backgroundColor = bgColor
        v.addSubview(iv)
        return v
    }
    
    func updateUIView(_ view: UIView, context: Context) {
        let iv = view.subviews[0] as! UIImageView
        
        var options: [CIImageOption : Any] = [:]
        options[.applyOrientationProperty] = true
        if #available(iOS 14.1, *) {
            options[.toneMapHDRtoSDR] = false
        }
        guard let image = CIImage(data: imageData, options: options) else { return }
        let wrap = UIImage(ciImage: image)
        
        iv.contentMode = .scaleAspectFit
        iv.image = wrap
    }

}


struct PlatformImageViewCIRenderCG : UIViewRepresentable, ImageDataConstructable {
    let imageData: Data
    
    func makeUIView(context: Context) -> UIView {
        let iv = UIImageView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        let v = UIView(frame: iv.frame)
        v.backgroundColor = bgColor
        v.addSubview(iv)
        return v
    }
    
    func updateUIView(_ view: UIView, context: Context) {
        let iv = view.subviews[0] as! UIImageView
        
        var options: [CIImageOption : Any] = [:]
        options[.applyOrientationProperty] = true
        if #available(iOS 14.1, *) {
            options = [CIImageOption.toneMapHDRtoSDR: false]
        }
        guard let image = CIImage(data: imageData, options: options) else { return }
        guard let device = MTLCreateSystemDefaultDevice() else { return }
        let ctx = CIContext(mtlDevice: device)
        let name = CGColorSpace.extendedLinearDisplayP3
        let space = CGColorSpace(name: name)
        
        guard let rendered = ctx.createCGImage(image, from: image.extent, format: .RGBAh, colorSpace: space) else { return }
        
        let wrap = UIImage(cgImage: rendered)
        
        iv.contentMode = .scaleAspectFit
        iv.image = wrap
    }

}


struct PlatformImageViewCIRenderCGSource : UIViewRepresentable, ImageDataConstructable {
    let imageData: Data
    
    func makeUIView(context: Context) -> UIView {
        let iv = UIImageView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        let v = UIView(frame: iv.frame)
        v.backgroundColor = bgColor
        v.addSubview(iv)
        return v
    }
    
    func updateUIView(_ view: UIView, context: Context) {
        let iv = view.subviews[0] as! UIImageView
        
        guard let image = loadCIImageWithCGSource(imageData: imageData) else { return }

        guard let device = MTLCreateSystemDefaultDevice() else { return }
        let ctx = CIContext(mtlDevice: device)
        let name = CGColorSpace.extendedLinearDisplayP3
        let space = CGColorSpace(name: name)
        
        guard let rendered = ctx.createCGImage(image, from: image.extent, format: .RGBAh, colorSpace: space) else { return }
//
        let wrap = UIImage(cgImage: rendered)
//        let wrap = UIImage(ciImage: image)
        
        iv.contentMode = .scaleAspectFit
        iv.image = wrap
    }

}


struct MetalImageViewCIRenderCGSource : UIViewRepresentable, ImageDataConstructable {
    let imageData: Data
    
    class Renderer : NSObject, MTKViewDelegate {
        
        var context: CIContext?
        var commandQueue: MTLCommandQueue?
        
        var image: CIImage?
        
        func setupMetal(_ view: MTKView) {
            guard let layer = view.layer as? CAMetalLayer else { return }
            
            guard let device = view.preferredDevice ?? MTLCreateSystemDefaultDevice() else { return }
            view.device = device
            
            commandQueue = device.makeCommandQueue()
            commandQueue?.label = String(describing: Self.self)
            
            guard let commandQueue = commandQueue else { return }
            
            let options: [CIContextOption : Any] = [
                .cacheIntermediates: false,
                .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)!,
            ]
            context = CIContext(mtlCommandQueue: commandQueue, options: options)
            
            // allow CI to write to fb
            view.framebufferOnly = false
            view.colorPixelFormat = .rgba16Float
            view.clearColor = MTLClearColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            view.delegate = self
            
            
            layer.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
            
            // Not doing anything
            // layer.wantsExtendedDynamicRangeContent = true
            // layer.setValue(true, forKey: "wantsExtendedDynamicRangeContent")
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            
        }
        
        func draw(in view: MTKView) {
            guard let context = context,
                  var image = image,
                  let layer = view.layer as? CAMetalLayer,
                  let drawable = view.currentDrawable,
                  let colorSpace = layer.colorspace,
                  let commandBuffer = commandQueue?.makeCommandBuffer()
            else {
                return
            }
            let texture = drawable.texture

            image = aspectFitToDestination(image: image, destination: view.drawableSize)
            
//            image = image.adjustExposure(ev: 2.0)!
            
            context.render(image, to: texture, commandBuffer: commandBuffer, bounds: image.extent, colorSpace: colorSpace)
            
            commandBuffer.present(drawable)
            
            commandBuffer.commit()
        }
        
    }
    
    func makeCoordinator() -> Renderer {
        return Renderer()
    }
    
    func makeUIView(context: Context) -> UIView {
        let iv = MTKView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        let v = UIView(frame: iv.frame)
        v.backgroundColor = bgColor
        v.addSubview(iv)
        context.coordinator.setupMetal(iv)
        return v
    }
    
    func updateUIView(_ view: UIView, context: Context) {
        let iv = view.subviews[0] as! MTKView
        let (image, usedGain) = loadCIImageWithGainMap(imageData: imageData)
        context.coordinator.image = image
        iv.setNeedsDisplay()
    }

}
