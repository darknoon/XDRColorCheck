//
//  ViewUtils.swift
//  XDRColorCheck
//
//  Created by Andrew Pouliot on 10/28/20.
//

import SwiftUI

let mediaSize = CGSize(width: 150, height: 150)

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
