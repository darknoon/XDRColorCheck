//
//  VideoView.swift
//  XDRColorCheck
//
//  Created by Andrew Pouliot on 10/28/20.
//

import SwiftUI
import AVFoundation
import CoreImage.CIFilterBuiltins

// Util class to show an AVPlayerLayer
class PlayerView : UIView {
    let player: AVPlayer
    override init(frame: CGRect) {
        player = AVPlayer(playerItem: nil)
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


struct AVPlayerLayerVideoView : UIViewRepresentable {
    
    
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


struct FilteredAVPlayerLayerVideoView : UIViewRepresentable {
    
    let videoURL: URL
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    func makeUIView(context: Context) -> PlayerView {
        return PlayerView(frame: CGRect(origin: .zero, size: mediaSize))
    }
    
    
    func updateUIView(_ view: PlayerView, context: Context) {

        let item = AVPlayerItem(url: videoURL)
        
        guard let device = MTLCreateSystemDefaultDevice(),
              let workingSpace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3) else { return }
        
        let context = CIContext(mtlDevice: device, options: [
            .workingFormat: CIFormat.RGBAh,
            .workingColorSpace: workingSpace
        ])
        
        // From Edit and Play Back video in HDR
        let vc = AVMutableVideoComposition(asset: item.asset) { (request: AVAsynchronousCIImageFilteringRequest) in
            // Example from WWDC session doesn't work :(
            // let f = CIFilter.zoomBlur()
            // f.inputImage = request.sourceImage
            // f.amount = 0.2
            
            let f = CIFilter.gaussianBlur()
            f.inputImage = request.sourceImage
            f.radius = 3.0
            
            if let outputImage = f.outputImage {
                // Also doesn't work when I set context = nil
                request.finish(with: outputImage, context: context)
            } else {
                request.finish(with: VideoError.filterError)
            }
        }
        
        item.videoComposition = vc

        let player = view.player
        player.replaceCurrentItem(with: item)
        
        player.play()
    }
    
}



