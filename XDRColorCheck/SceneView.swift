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

func *(left: CGRect, scale: CGFloat) -> CGRect {
        .init(x: left.origin.x * scale, y: left.origin.y * scale, width: left.size.width * scale, height: left.self.height * scale )
}

// 2. Try to render HDR content using video APIs

//struct SceneKitInPlayerLayerView: UIViewRepresentable {
//
//    class Coordinator
//}
