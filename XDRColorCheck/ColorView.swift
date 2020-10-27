//
//  ColorView.swift
//  XDRColorCheck
//
//  Created by Andrew Pouliot on 10/26/20.
//

import SwiftUI

#if os(macOS)

typealias PlatformColor = NSColor

// Lets us make sure we are setting a real CALayer property.
struct ColorView : NSViewRepresentable {
    let color: NSColor
    
    func makeNSView(context: Context) -> some NSView {
        let v =  NSView()
        v.wantsLayer = true
        v.layer?.backgroundColor = color.cgColor
        return v
    }
    
    func updateNSView(_ view: NSViewType, context: Context) {
        view.layer?.backgroundColor = color.cgColor
    }
}

extension NSColor {
    convenience init?(spaceName: CFString, components: [CGFloat]) {
        guard let space = CGColorSpace(name: spaceName) else { return nil}
        guard let cgc = CGColor(colorSpace: space, components: components) else { return nil }
        self.init(cgColor: cgc)
    }
}


#elseif os(iOS)

typealias PlatformColor = UIColor

// Lets us make sure we are setting a real CALayer property.
struct ColorView : UIViewRepresentable {
    let color: UIColor
    
    func makeUIView(context: Context) -> some UIView {
        let v =  UIView()
        v.backgroundColor = color
        return v
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        uiView.backgroundColor = color
    }
}

extension UIColor {
    convenience init?(spaceName: CFString, components: [CGFloat]) {
        guard let space = CGColorSpace(name: spaceName) else { return nil}
        guard let cgc = CGColor(colorSpace: space, components: components) else { return nil }
        self.init(cgColor: cgc)
    }
}

#endif

func makeGrey(spaceName: CFString, value: CGFloat) -> PlatformColor! {
    return PlatformColor(spaceName: spaceName, components: [value, value, value, 1.0])
}
func makeRed(spaceName: CFString, value: CGFloat) -> PlatformColor! {
    return PlatformColor(spaceName: spaceName, components: [value, 0.0, 0.0, 1.0])
}
func makeGreen(spaceName: CFString, value: CGFloat) -> PlatformColor! {
    return PlatformColor(spaceName: spaceName, components: [0.0, value, 0.0, 1.0])
}
func makeBlue(spaceName: CFString, value: CGFloat) -> PlatformColor! {
    return PlatformColor(spaceName: spaceName, components: [0.0, 0.0, value, 1.0])
}
