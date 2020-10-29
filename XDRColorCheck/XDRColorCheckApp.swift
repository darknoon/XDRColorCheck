//
//  XDRColorCheckApp.swift
//  XDRColorCheck
//
//  Created by Andrew Pouliot on 10/25/20.
//

import SwiftUI

@main
struct XDRColorCheckApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                ColorList()
                    .tabItem {
                        Image(systemName: "paintpalette")
                        Text("Colors")
                    }
                ImageList()
                    .tabItem {
                        Image(systemName: "photo.on.rectangle")
                        Text("Images")
                    }
                VideoList()
                    .tabItem {
                        Image(systemName: "video")
                        Text("Video")
                    }
            }
        }
    }
}
