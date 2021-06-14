//
//  SceneView.swift
//  XDRColorCheck
//
//  Created by Andrew Pouliot on 6/14/21.
//

import Foundation
import SwiftUI
import SceneKit
import MetalKit
import AVFoundation

// 1. Try to render HDR content naively
struct SceneKitView: UIViewRepresentable, SceneURLConstructable {
    
    let scene: URL
    
    let colorSpaceName = CGColorSpace.extendedLinearDisplayP3
    
    class Coordinator: NSObject, MTKViewDelegate {
        let scene: SCNScene
        let renderer: SCNRenderer
        let device: MTLDevice
        let commandQueue: MTLCommandQueue
        
        init(sceneURL: URL) {
            scene = try! SCNScene(url: sceneURL, options: nil)
            device = MTLCreateSystemDefaultDevice()!
            commandQueue = device.makeCommandQueue()!
            renderer = SCNRenderer(device: device, options: nil)
            renderer.scene = scene
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            
        }
        
        func draw(in view: MTKView) {
            guard let cmd = commandQueue.makeCommandBuffer(),
                  let pass = view.currentRenderPassDescriptor,
                  let drawable = view.currentDrawable
            else { return }
            renderer.render(withViewport: view.bounds * view.contentScaleFactor, commandBuffer: cmd, passDescriptor: pass)
            cmd.present(drawable)
            cmd.commit()
        }
    }
    
    func makeUIView(context: Context) -> some UIView {
        let view = MTKView(frame: .zero, device: context.coordinator.device)
        guard let layer = view.layer as? CAMetalLayer
        else { fatalError("Wrong layer class")}
        view.colorPixelFormat = .rgba16Float
        view.delegate = context.coordinator
        layer.colorspace = CGColorSpace(name: colorSpaceName)!
        return view
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {}


    func makeCoordinator() -> Coordinator {
        Coordinator(sceneURL: scene)
    }
}

// 2. Try to render HDR content using video APIs



struct SceneKitInPlayerLayerView : UIViewRepresentable, SceneURLConstructable {
    
    // Bogus video that just happens to be in HLG
    let videoURL = Bundle.main.url(forResource: "IMG_1239.MOV", withExtension: nil)!
    let scene: URL
    
    let colorSpaceName = CGColorSpace.extendedLinearDisplayP3
    
    // CIFilter that renders a SceneKit scene
    class SceneKitFilter: CIImageProcessorKernel {
        
        // TODO: There is a better way to express [Key: Any].init(_ [Key.RawType: Any]) right?
        struct Inputs {
            let sceneRenderer: SCNRenderer
            let time: CMTime

            init(sceneRenderer: SCNRenderer, time: CMTime) {
                self.sceneRenderer = sceneRenderer
                self.time = time
            }


            init?(from dict: [String : Any]) {
                guard
                    let sceneRenderer = dict[Key.sceneRenderer.rawValue] as? SCNRenderer,
                    let time = dict[Key.time.rawValue] as? CMTime
                else { return nil }
                self.sceneRenderer = sceneRenderer
                self.time = time
            }
            
            var dict: [String: Any] {
                [
                    Key.sceneRenderer.rawValue : sceneRenderer,
                    Key.time.rawValue : time,
                ]
            }

            private enum Key : String, RawRepresentable {
                case sceneRenderer
                case time
            }

        }
        
        override class func process(with inputs: [CIImageProcessorInput]?, arguments: [String : Any]?, output: CIImageProcessorOutput) throws {
            guard
                let arguments = arguments.flatMap(Inputs.init),
                let commandBuffer = output.metalCommandBuffer,
                let input = inputs?.first,
                // We don't actually care about the input metal texture, haha…
                let sourceTexture = input.metalTexture,
                let destinationTexture = output.metalTexture
            else { return } // Should we throw?
            
            let device = destinationTexture.device
            
//            let depthTexture = device.makeTexture(descriptor: )
            
            let renderPass  = MTLRenderPassDescriptor()
            renderPass.colorAttachments[0].texture = destinationTexture
            
//            renderer.render(withViewport: output.region, commandBuffer: commandBuffer, passDescriptor: renderPass)
            arguments.sceneRenderer.render(atTime: arguments.time.seconds, viewport: output.region, commandBuffer: commandBuffer, passDescriptor: renderPass)
            
            
        }
    }

    class Coordinator {
        let scene: SCNScene
        let renderer: SCNRenderer
        let device: MTLDevice
        let commandQueue: MTLCommandQueue
        
        init(sceneURL: URL) {
            scene = try! SCNScene(url: sceneURL, options: nil)
            device = MTLCreateSystemDefaultDevice()!
            commandQueue = device.makeCommandQueue()!
            renderer = SCNRenderer(device: device, options: nil)
            renderer.scene = scene
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(sceneURL: scene)
    }
    
    func makeUIView(context: Context) -> PlayerView {
        return PlayerView(frame: CGRect(origin: .zero, size: mediaSize))
    }
    
    func updateUIView(_ view: PlayerView, context: Context) {

        let item = AVPlayerItem(url: videoURL)
        
        // This code is from "Edit and Play Back video in HDR" https://developer.apple.com/videos/play/wwdc2020/10009/
        let vc = AVMutableVideoComposition(asset: item.asset, applyingCIFiltersWithHandler: { (request: AVAsynchronousCIImageFilteringRequest) in

            do {
                let inputs = SceneKitFilter.Inputs(
                    sceneRenderer: context.coordinator.renderer,
                    time: request.compositionTime
                )
                let outputImage = try SceneKitFilter.apply(withExtent: request.sourceImage.extent, inputs: [request.sourceImage], arguments: inputs.dict)
                request.finish(with: outputImage, context: nil)
            } catch {
                request.finish(with: VideoError.filterError)
            }
        })
        
        // Not supposed to be required per WWDC session, but shows in SDR otherwise (FB8834066)
        vc.colorPrimaries = AVVideoColorPrimaries_P3_D65
        vc.colorTransferFunction = AVVideoTransferFunction_ITU_R_2100_HLG
        vc.colorYCbCrMatrix = AVVideoYCbCrMatrix_ITU_R_2020
        
        item.videoComposition = vc

        let player = view.player
        player.replaceCurrentItem(with: item)
        
        player.play()
    }
    
}


