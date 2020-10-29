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

protocol ImageDataConstructable {
    init(imageData: Data)
}

func erase<T: ImageDataConstructable>(_ viewType: T) -> (String, (Data) -> AnyView) where T:View {
    return (String(describing: viewType), {data in AnyView(T.init(imageData: data)) } )
}

let regex = try! NSRegularExpression(pattern: "Mirror for \\(.*\\) ->", options: [])

func cleanupDescription(_ blah: String) -> String {
    return regex.stringByReplacingMatches(in: blah, options: [], range: NSRange(location: 0, length: blah.count), withTemplate: "")
//    return blah.replacingOccurrences(of: "Mirror for (Data) ->", with: "")
}

func eraseInit<T, Input>(_ initFunc: @escaping (Input) -> T) -> (String, (Input) -> AnyView) where T:View {
    return (cleanupDescription(String(describing: Mirror(reflecting: initFunc))), {data in AnyView(initFunc(data)) } )
}


// Oh just a buncha parallel implementations
let attempts = [
    eraseInit(PlatformImageView.init),
    eraseInit(PlatformImageViewCI.init),
    eraseInit(PlatformImageViewCIRenderCG.init),
    eraseInit(PlatformImageViewCIRenderCGSource.init),
    eraseInit(MetalImageViewCIRenderCGSource.init),
    eraseInit(LivePhotoImageView.init),
].reversed()

struct ImageList : View {
    var body: some View {
        List {
            Text("The background of each image view is P3 white, so any brighter colors indicate HDR.")
                .padding(.top, 60)
                .padding(.bottom, 30)
            ForEach(testImages, id: \.2) {(name, hdrType, fileName) in
                if  let resource = Bundle.main.url(forResource: fileName, withExtension: nil),
                    let data = try? Data(contentsOf: resource) {
                    VStack {
                        HStack {
                            Text(fileName)
                                .font(.headline)
                            BadgeView(text: String(describing: hdrType))
                        }
                        ForEach(attempts, id: \.0) { name, constructor in
                            VStack() {
                                constructor(data)
                                    .frame(width: mediaSize.width, height: mediaSize.height)
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

