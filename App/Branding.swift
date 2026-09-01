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
