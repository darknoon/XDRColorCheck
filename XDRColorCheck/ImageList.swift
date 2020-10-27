//
//  ImageList.swift
//  XDRColorCheck
//
//  Created by Andrew Pouliot on 10/26/20.
//

import Foundation
import SwiftUI

enum HDRType {
    case smartHDR3
}

let testImages: [(String, HDRType, String)] = [
    ("iPhone 12", .smartHDR3, "IMG_1201.HEIC")
]

// Oh just a buncha parallel implementations
let attempts: [(String, (Data) -> AnyView)] = [
    (String(describing: PlatformImageView.self),
     {data in AnyView(PlatformImageView.init(imageData: data))}),
    
    ("PlatformImageViewCI",
     {data in AnyView(PlatformImageViewCI.init(imageData: data))}),
    
    ("PlatformImageViewCIRenderCG",
     {data in AnyView(PlatformImageViewCIRenderCG.init(imageData: data))}),
    
    ("MetalImageViewCIRenderCGSource",
     {data in AnyView(MetalImageViewCIRenderCGSource.init(imageData: data))})
]

struct ImageList : View {
    var body: some View {
        List {
            ForEach(testImages, id: \.2) {(name, hdrType, fileName) in
                if  let resource = Bundle.main.url(forResource: fileName, withExtension: nil),
                    let data = try? Data(contentsOf: resource) {
                    VStack {
                        ForEach(attempts, id: \.0) { name, constructor in
                            VStack() {
                                constructor(data)
                                    .frame(width: 300, height: 300)
                                Text(name)
                            }.padding()
                        }
                    }
                } else {
                    Text("Could not load image ") + Text(verbatim: fileName)
                }
            }
        }
    }
}

struct ImageList_Previews: PreviewProvider {
    static var previews: some View {
        ImageList()
    }
}

