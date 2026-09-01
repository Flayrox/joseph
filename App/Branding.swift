import AppKit
import SwiftUI

enum JosephBranding {
    static func image(named name: String) -> NSImage {
        let candidates: [URL?] = [
            Bundle.main.url(forResource: name, withExtension: nil),
            Bundle.main.resourceURL?.appendingPathComponent(name),
            Bundle.main.resourceURL?.appendingPathComponent("Resources").appendingPathComponent(name)
        ]
        for candidate in candidates.compactMap({ $0 }) {
            if let image = NSImage(contentsOf: candidate) {
                return image
            }
        }
        return NSImage(size: NSSize(width: 1, height: 1))
    }

    static var menuBarImage: NSImage {
        let image = image(named: "logo_outline.png")
        image.isTemplate = true
        return image
    }
}

struct JosephMenuBarIcon: View {
    var body: some View {
        Image(nsImage: JosephBranding.menuBarImage)
            .resizable()
            .renderingMode(.template)
            .aspectRatio(contentMode: .fit)
            .frame(width: 18, height: 18)
            .accessibilityLabel("joseph")
    }
}

struct JosephOutlineLogo: View {
    var body: some View {
        Image(nsImage: JosephBranding.image(named: "logo_outline.png"))
            .resizable()
            .scaledToFit()
    }
}

struct JosephFilledLogo: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
            Image(nsImage: JosephBranding.image(named: "logo_fill.jpg"))
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(4)
        }
    }
}
