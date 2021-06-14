//
//  SceneList.swift
//  XDRColorCheck
//
//  Created by Andrew Pouliot on 6/14/21.
//

import SwiftUI

let testScenes: [(displayName: String, resourceName: String)] = [
    ("Test Scene", "TestScene.scn")
]

let sceneAttempts = [
//    eraseInit(SceneKitView.init),
    eraseInit(SceneKitInPlayerLayerView.init)
].reversed()

protocol SceneURLConstructable {
    init(scene: URL)
}


struct SceneList : View {
    
    var body: some View {
        List {
            ForEach(testScenes, id: \.resourceName) {(name, fileName) in
                VStack(alignment: .leading) {
                    if let sceneURL = Bundle.main.url(forResource: fileName, withExtension: nil) {
                        ForEach(sceneAttempts, id: \.0) {(name, constructor) in
                            VStack() {
                                constructor(sceneURL)
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
