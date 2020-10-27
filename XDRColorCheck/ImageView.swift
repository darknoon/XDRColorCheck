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
        let name = CGColorSpace.extendedDisplayP3
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
        let name = CGColorSpace.extendedDisplayP3
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
            
            guard let device = view.preferredDevice ?? MTLCreateSystemDefaultDevice() else { return }
            view.device = device
            
            commandQueue = device.makeCommandQueue()
            commandQueue?.label = String(describing: Self.self)
            
            guard let commandQueue = commandQueue else { return }
            
            context = CIContext(mtlCommandQueue: commandQueue, options: [CIContextOption.cacheIntermediates: false])
            
            let layer = view.layer as! CAMetalLayer
            // allow CI to write to fb
            view.framebufferOnly = false
            view.colorPixelFormat = .rgba16Float
            view.clearColor = MTLClearColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            view.delegate = self
            layer.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
            
            // Not doing anything
            // layer.setValue(true, forKey: "wantsExtendedDynamicRangeContent")
            // layer.wantsExtendedDynamicRangeContent = true
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            
        }
        
        func draw(in view: MTKView) {
            guard let context = context,
                  var image = image,
                  let layer = view.layer as? CAMetalLayer,
                  let drawable = view.currentDrawable,
                  let colorSpace = layer.colorspace
            else {
                return
            }
            let texture = drawable.texture

            image = aspectFitToDestination(image: image, destination: view.drawableSize)
            
            let brightFilter = CIFilter.exposureAdjust()
            brightFilter.ev = 1.0
            
            brightFilter.inputImage = image
            if let brighterImage = brightFilter.outputImage {
                image = brighterImage
            }
            
            context.render(image, to: texture, commandBuffer: nil, bounds: image.extent, colorSpace: colorSpace)
            
            drawable.present()
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
        context.coordinator.image = loadCIImageWithCGSource(imageData: imageData)
        iv.setNeedsDisplay()
    }

}
