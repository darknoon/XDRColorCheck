import SwiftUI

let values: [(String, CGFloat)] = [
    ("0.0", 0.0),
    ("1/12", 1.0 / 12),
    ("0.25", 0.25),
    ("0.5", 0.5),
    ("0.75", 0.75),
    ("1.0", 1.0),
    ("1.25", 1.25),
    ("2.0", 2.0),
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

extension UIColor {
    convenience init?(spaceName: CFString, components: [CGFloat]) {
        guard let space = CGColorSpace(name: spaceName) else { return nil}
        guard let cgc = CGColor(colorSpace: space, components: components) else { return nil }
        self.init(cgColor: cgc)
    }
}

func makeGrey(spaceName: CFString, value: CGFloat) -> UIColor! {
    return UIColor(spaceName: spaceName, components: [value, value, value, 1.0])
}
func makeRed(spaceName: CFString, value: CGFloat) -> UIColor! {
    return UIColor(spaceName: spaceName, components: [value, 0.0, 0.0, 1.0])
}
func makeGreen(spaceName: CFString, value: CGFloat) -> UIColor! {
    return UIColor(spaceName: spaceName, components: [0.0, value, 0.0, 1.0])
}
func makeBlue(spaceName: CFString, value: CGFloat) -> UIColor! {
    return UIColor(spaceName: spaceName, components: [0.0, 0.0, value, 1.0])
}

let ramps = [("y", makeGrey), ("r", makeRed), ("g", makeGreen), ("b", makeBlue)]


let srgbWhite = UIColor(cgColor: CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [1.0, 1.0, 1.0, 1.0])!)

let a = spaces.flatMap{
    (name, spaceName) in
    values.map{
        (valueName, value) in
        ("\(name) \(valueName)", makeGrey(spaceName: spaceName, value: value))
    }
}

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

var columns: [GridItem] =
    Array(repeating: .init(.flexible()), count: 3)

struct ContentView: View {
    var body: some View {
        GeometryReader { px in
            let h: CGFloat = px.size.width / CGFloat(values.count + 1)
            List {
                ForEach(spaces, id: \.0) {(spaceLabel, spaceName) in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(spaceLabel)
                            .font(Font.headline)
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
                            ColorView(color: fn(spaceName, 1.0)!)
                                .frame(width: CGFloat(values.count) * h, height: h/4, alignment: .topLeading)
                        }
                    }
                    .padding(.bottom, 30)
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
        ContentView()
    }
}
