import SwiftUI

let values: [(String, CGFloat)] = [
    ("0.0",  0.0),
    ("1/12", 1.0 / 12),
    ("0.25", 0.25),
    ("0.5",  0.5),
    ("0.75", 0.75),
    ("1.0",  1.0),
    ("1.25", 1.25),
    ("2.0",  2.0),
    ("4.0",  4.0),
    ("12",   12.0),
]

let spaces: [(String, CFString)] = [
    ("sRGB", CGColorSpace.sRGB),
    ("Display P3", CGColorSpace.displayP3),
    ("Display P3 Extended Linear", CGColorSpace.extendedLinearDisplayP3),
    ("Display P3—HLG",CGColorSpace.displayP3_HLG),
    ("Display P3—PQ",CGColorSpace.displayP3_PQ),
    
    ("Rec.2100 HLG", kCGColorSpaceITUR_2100_HLG),
    ("Rec.2100 PQ", kCGColorSpaceITUR_2100_PQ),
]


let ramps = [("y", makeGrey), ("r", makeRed), ("g", makeGreen), ("b", makeBlue)]

var columns: [GridItem] =
    Array(repeating: .init(.flexible()), count: 3)

struct ColorList: View {
    var body: some View {
        GeometryReader { px in
            List {
                // Can turn on a player above here to increase the EDR room
                // AVPlayerLayerVideoView(videoURL: videoURL, playing: true)
                //   .background(Color.white)

                // Max each chip relative to the width
                let h: CGFloat = px.size.width / CGFloat(values.count + 1)
                ForEach(spaces, id: \.0) {(spaceLabel, spaceName) in
                    VStack(spacing: 0) {
                        Text(spaceLabel)
                            .font(Font.headline)
                            .padding(.bottom, 5)
                        ForEach(ramps, id: \.0) { _, fn in
                            HStack(spacing: 0) {
                                ForEach(values, id: \.0) {(valueLabel, value) in
                                    ColorView(color: fn(spaceName, value)!)
                                        .frame(width: h, height: h, alignment: .leading)
                                        .overlay(
                                            Text(valueLabel)
                                                .font(.caption2)
                                        )
                                }
                            }
                            // Draw a bar below the colors with component set to 1 in Display P3
                            ColorView(color: fn(CGColorSpace.displayP3, 1.0)!)
                                .frame(width: CGFloat(values.count) * h, height: h/4, alignment: .topLeading)
                        }
                    }
                    .padding(.bottom, 5)
                    .listRowBackground(Color.gray)
                }
                Text("If you're reading this, you have XDR!")
                    .font(.headline)
                    .foregroundColor(
                        Color(makeGrey(spaceName: CGColorSpace.extendedLinearDisplayP3, value: 2.0)))
                    .background(
                        Color(makeGrey(spaceName: CGColorSpace.displayP3, value: 1.0)!))
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ColorList()
        }
    }
}
