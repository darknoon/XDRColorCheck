//
//  ViewUtils.swift
//  XDRColorCheck
//
//  Created by Andrew Pouliot on 10/28/20.
//

import SwiftUI

// MARK: Stupid Constants

let mediaSize = CGSize(width: 300, height: 150)


// MARK: Erase a constructor for a SwiftUI View
let regex = try! NSRegularExpression(pattern: "Mirror for \\(.*\\) ->", options: [])

func cleanupDescription(_ blah: String) -> String {
    return regex.stringByReplacingMatches(in: blah, options: [], range: NSRange(location: 0, length: blah.count), withTemplate: "")
}

func eraseInit<T, Input>(_ initFunc: @escaping (Input) -> T) -> (String, (Input) -> AnyView) where T:View {
    return (cleanupDescription(String(describing: Mirror(reflecting: initFunc))), {data in AnyView(initFunc(data)) } )
}

func *(left: CGRect, scale: CGFloat) -> CGRect {
        .init(x: left.origin.x * scale, y: left.origin.y * scale, width: left.size.width * scale, height: left.self.height * scale )
}


// MARK: Badge View

struct BadgeView : View {
    
    let text: String
    
    let color = Color.gray
    
    var body: some View {
        return Text(text)
            .foregroundColor(color)
            .padding(1.5)
            .background(Color.white)
            .cornerRadius(2)
            .font(.caption2)
            .padding(.all, 1)
            .background(color)
            .cornerRadius(2 + 1)
            .padding(2)
    }
}

struct ViewUtils_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            BadgeView(text: "HDR")
            BadgeView(text: "Dolby 8.4")
        }
        .previewLayout(.sizeThatFits)
    }
}
