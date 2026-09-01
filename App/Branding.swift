import AppKit
import SwiftUI

enum JosephBranding {
    static func image(named name: String) -> NSImage {
        if let image = NSImage(named: name) { return image }
        if let image = NSImage(contentsOf: resourceURL(named: name)) { return image }
        return NSImage(size: NSSize(width: 1, height: 1))
    }

    static func resourceURL(named name: String) -> URL {
        Bundle.main.resourceURL?.appendingPathComponent("Resources").appendingPathComponent(name)
            ?? URL(fileURLWithPath: name)
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
