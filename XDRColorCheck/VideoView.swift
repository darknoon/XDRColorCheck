//
//  VideoView.swift
//  XDRColorCheck
//
//  Created by Andrew Pouliot on 10/28/20.
//

import SwiftUI
import AVFoundation
import CoreImage.CIFilterBuiltins

protocol VideoURLConstructable {
    init(videoURL: URL)
}

// Util class to show an AVPlayerLayer
class PlayerView : UIView {
    let player: AVPlayer
    override init(frame: CGRect) {
        player = AVPlayer(playerItem: nil)
        player.isMuted = true
        super.init(frame: frame)
        if let playerLayer = self.layer as? AVPlayerLayer {
            playerLayer.player = player
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override class var layerClass: AnyClass { AVPlayerLayer.self }
}

enum VideoError : Error {
    case filterError
}

// 1. Simplest possible way to play a video
struct AVPlayerLayerVideoView : UIViewRepresentable, VideoURLConstructable {
    
    let videoURL: URL
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    func makeUIView(context: Context) -> PlayerView {
        return PlayerView(frame: CGRect(origin: .zero, size: mediaSize))
    }
    
    func updateUIView(_ view: PlayerView, context: Context) {
        let item = AVPlayerItem(url: videoURL)
        let player = view.player
        player.replaceCurrentItem(with: item)
        
        player.play()
    }
    
}

// 2. Play a video with a CIFilter
struct FilteredAVPlayerLayerVideoView : UIViewRepresentable, VideoURLConstructable {
    
    let videoURL: URL
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    func makeUIView(context: Context) -> PlayerView {
        return PlayerView(frame: CGRect(origin: .zero, size: mediaSize))
    }
    
    
    func updateUIView(_ view: PlayerView, context: Context) {

        let item = AVPlayerItem(url: videoURL)
        
        // This code is from "Edit and Play Back video in HDR" https://developer.apple.com/videos/play/wwdc2020/10009/
        let vc = AVMutableVideoComposition(asset: item.asset, applyingCIFiltersWithHandler: { (request: AVAsynchronousCIImageFilteringRequest) in
            let f = CIFilter.gaussianBlur()
            f.inputImage = request.sourceImage
            f.radius = 3.0
            
            if let outputImage = f.outputImage {
                request.finish(with: outputImage, context: nil)
            } else {
                request.finish(with: VideoError.filterError)
            }
        })
        
        // Not supposed to be required per WWDC session, but shows in SDR otherwise (FB8834066)
        vc.colorPrimaries = AVVideoColorPrimaries_ITU_R_2020
        vc.colorTransferFunction = AVVideoTransferFunction_ITU_R_2100_HLG
        vc.colorYCbCrMatrix = AVVideoYCbCrMatrix_ITU_R_2020
        
        item.videoComposition = vc

        let player = view.player
        player.replaceCurrentItem(with: item)
        
        player.play()
    }
    
}

// 3. Render a video into a metal view with a CIFilter
import MetalKit
struct MetalAVPlayerItemVideoOutputVideoView : UIViewRepresentable, VideoURLConstructable {

    let videoURL: URL

    class Coordinator : NSObject, MTKViewDelegate {
        
        let device = MTLCreateSystemDefaultDevice()!
        var videoDataOutput: AVPlayerItemVideoOutput? = nil
        var currentFrame : CVPixelBuffer? = nil
        let context: CIContext
        let workingColorSpace = CGColorSpace(name: CGColorSpace.extendedLinearITUR_2020)!
        let outputColorSpace = CGColorSpace(name: kCGColorSpaceITUR_2100_HLG)!

        let player = AVPlayer(playerItem: nil)

        override init() {
            context = CIContext(mtlDevice: device, options: [
                .workingFormat: CIFormat.RGBAh,
                .workingColorSpace: workingColorSpace
            ])
            player.isMuted = true
        }
        
        var playerItem: AVPlayerItem? {
            didSet {
                if let oldOutput = videoDataOutput {
                    oldValue?.remove(oldOutput)
                }
                
                if let playerItem = playerItem {
                    
                    let output = AVPlayerItemVideoOutput(pixelBufferAttributes: [
                        String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_420YpCbCr10BiPlanarFullRange,
                    ])
                    playerItem.add(output)
                    videoDataOutput = output
                }

                player.replaceCurrentItem(with: playerItem)
            }
        }
        
        func requestFrame() {
            let t = player.currentTime()
            // Get next frame
            if let videoDataOutput = videoDataOutput,
               videoDataOutput.hasNewPixelBuffer(forItemTime: t) {
                if let next = videoDataOutput.copyPixelBuffer(forItemTime: t, itemTimeForDisplay: nil) {
                    currentFrame = next
                }
            }
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
        
        func draw(in view: MTKView) {
            requestFrame()
            
            guard let currentFrame = currentFrame else { return }
            
            let cvWidth = CVPixelBufferGetWidth(currentFrame)
            let cvHeight = CVPixelBufferGetHeight(currentFrame)
            if cvWidth != Int(view.drawableSize.width) || cvHeight != Int(view.drawableSize.height) {
                print("Updated drawable to match video frame: \((cvWidth, cvHeight))")
                view.drawableSize = CGSize(width: cvWidth, height: cvHeight)
            }
            
            guard let drawable = view.currentDrawable else { return }
            
            var options: [CIImageOption : Any] = [:]
            options[.applyOrientationProperty] = true
            if #available(iOS 14.1, *) {
                // This seems to do nothing :(
                options[.toneMapHDRtoSDR] = false
            }

            let im = CIImage(cvPixelBuffer: currentFrame, options: options)

            // Filter image
            let f = CIFilter.gaussianBlur()
            f.inputImage = im
            f.radius = 3.0
            let outputImage = f.outputImage!

            context.render(outputImage, to: drawable.texture, commandBuffer: nil, bounds: im.extent, colorSpace: outputColorSpace)
            
            drawable.present()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    func makeUIView(context: Context) -> MTKView {
        let v = MTKView(frame: CGRect(origin: .zero, size: mediaSize))
        v.device = context.coordinator.device
        v.framebufferOnly = false
        v.colorPixelFormat = .rgba16Float
        v.autoResizeDrawable = false
        v.delegate = context.coordinator
        let metalLayer = v.layer as! CAMetalLayer
        metalLayer.setValue(true, forKey: "allowsDisplayCompositing")
        metalLayer.colorspace = context.coordinator.outputColorSpace
        return v
    }
    
    func updateUIView(_ v: MTKView, context: Context) {
        let item = AVPlayerItem(url: videoURL)
        let player = context.coordinator.player
        context.coordinator.playerItem = item
        player.play()
    }
    
}

// 4. Render a video into a view with IOSurface
import IOSurface
struct IOSurfaceAVPlayerItemVideoOutputVideoView : UIViewRepresentable, VideoURLConstructable {

    let videoURL: URL

    class Coordinator : NSObject {
        
        let device = MTLCreateSystemDefaultDevice()!
        var videoDataOutput: AVPlayerItemVideoOutput? = nil
        var currentFrame : CVPixelBuffer? = nil
        let context: CIContext
        let workingColorSpace = CGColorSpace(name: CGColorSpace.extendedLinearITUR_2020)!
        let outputColorSpace = CGColorSpace(name: kCGColorSpaceITUR_2100_HLG)!
        var displayLink: CADisplayLink?
        var outputLayer: CALayer?

        let player = AVPlayer(playerItem: nil)

        override init() {
            context = CIContext(mtlDevice: device, options: [
                .workingFormat: CIFormat.RGBAh,
                .workingColorSpace: workingColorSpace
            ])
            player.isMuted = true
        }
        
        var playerItem: AVPlayerItem? {
            didSet {
                if let oldOutput = videoDataOutput {
                    oldValue?.remove(oldOutput)
                }
                
                if let playerItem = playerItem {
                    let output = AVPlayerItemVideoOutput(pixelBufferAttributes: [
                        String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_420YpCbCr10BiPlanarFullRange,
                    ])
                    playerItem.add(output)
                    videoDataOutput = output
                }

                player.replaceCurrentItem(with: playerItem)
            }
        }
        
        func startDisplayLink() {
            displayLink = CADisplayLink(target: self, selector: #selector(Self.tick(displayLink:)))
            displayLink?.add(to: RunLoop.main, forMode: .common)
        }
        
        func requestFrame() {
            let t = player.currentTime()
            // Get next frame
            if let videoDataOutput = videoDataOutput,
               videoDataOutput.hasNewPixelBuffer(forItemTime: t) {
                if let next = videoDataOutput.copyPixelBuffer(forItemTime: t, itemTimeForDisplay: nil) {
                    currentFrame = next
                }
            }
        }
        
        @objc func tick(displayLink: CADisplayLink) {
            requestFrame()
            if let currentFrame = currentFrame {
                let surface = renderFrameToIOSurface(frame: currentFrame)
                outputLayer!.contents = surface
                outputLayer?.transform = CATransform3DMakeScale(1.0001, 1.0001, 1.0)
            }
        }
        
        // render CVPixelBuffer
        func renderFrameToIOSurface(frame: CVPixelBuffer) -> IOSurface? {
            var options: [CIImageOption : Any] = [:]
            options[.applyOrientationProperty] = true
            let im = CIImage(cvPixelBuffer: frame, options: options)

            // Filter image
            let f = CIFilter.gaussianBlur()
            f.inputImage = im
            f.radius = 3.0
            let outputImage = f.outputImage!
            
            let cvWidth = CVPixelBufferGetWidth(frame)
            let cvHeight = CVPixelBufferGetHeight(frame)
            let cvPixFmt = kCVPixelFormatType_64RGBAHalf
            let mtlPixFmt = MTLPixelFormat.rgba16Float
            let outputColorSpaceName = kCGColorSpaceITUR_2100_HLG
            let bytesPerPixel = (16 / 8) * 4
            
            guard let ioSurf = IOSurface(properties: [
                .bytesPerRow: bytesPerPixel * cvWidth,
                .bytesPerElement: bytesPerPixel,
                .width: cvWidth,
                .height: cvHeight,
                .pixelFormat: cvPixFmt,
            ]) else { return nil }
            IOSurfaceSetValue(ioSurf as IOSurfaceRef, "IOSurfaceColorSpace" as CFString, outputColorSpaceName)
            
            let d = MTLTextureDescriptor()
            d.storageMode = .shared
            d.usage = [.shaderWrite]
            d.width = cvWidth
            d.height = cvHeight
            d.pixelFormat = mtlPixFmt
            
            guard let texture = device.makeTexture(descriptor: d, iosurface: ioSurf, plane: 0) else { return nil }

            context.render(outputImage, to: texture, commandBuffer: nil, bounds: im.extent, colorSpace: outputColorSpace)
            
            return ioSurf
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    func makeUIView(context: Context) -> UIView {
        // We can use a plain UIView since we set contents with IOSurface
        let v = UIView(frame: CGRect(origin: .zero, size: mediaSize))
        context.coordinator.outputLayer = v.layer
        context.coordinator.startDisplayLink()
        return v
    }
    
    func updateUIView(_ v: UIView, context: Context) {
        let item = AVPlayerItem(url: videoURL)
        let player = context.coordinator.player
        context.coordinator.playerItem = item
        player.play()
    }
    
    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.displayLink?.invalidate()
    }
}

