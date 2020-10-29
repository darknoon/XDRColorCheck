//
//  VideoList.swift
//  XDRColorCheck
//
//  Created by Andrew Pouliot on 10/28/20.
//

import SwiftUI

enum VideoHDRType {
    case dolbyVisionHLG
}

let testVideos: [(String, VideoHDRType, String)] = [
    ("iPhone 12 Dolby HDR", .dolbyVisionHLG, "IMG_1239.MOV")
]

let videoAttempts = [
    eraseInit(AVPlayerLayerVideoView.init),
    eraseInit(FilteredAVPlayerLayerVideoView.init),
    eraseInit(MetalAVPlayerItemVideoOutputVideoView.init),
    eraseInit(IOSurfaceAVPlayerItemVideoOutputVideoView.init),
].reversed()

let firstVideoURL = Bundle.main.url(forResource: testVideos[0].2, withExtension: nil)!


struct VideoList : View {
    
    var body: some View {
        List {
            ForEach(testVideos, id: \.2) {(name, hdrType, fileName) in
                VStack(alignment: .leading) {
                    let videoURL = Bundle.main.url(forResource: fileName, withExtension: nil)!
                    HStack {
                        Text(videoURL.lastPathComponent)
                            .font(.headline)
                        BadgeView(text: String(describing: hdrType))
                    }
                    if let videoURL = Bundle.main.url(forResource: fileName, withExtension: nil) {
                        ForEach(videoAttempts, id: \.0) {(name, constructor) in
                            VStack() {
                                constructor(videoURL)
                                    .frame(width: mediaSize.width, height: mediaSize.height)
                                    .background(Color.white)
                                Text(name)
                            }.padding()
                        }
                    } else {
                        
                    }
                }
            }
        }
    }
}

struct VideoList_Previews: PreviewProvider {
    static var previews: some View {
        VideoList()
    }
}

