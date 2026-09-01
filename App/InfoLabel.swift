import SwiftUI

struct InfoLabel: View {
    let text: String
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .help(text)
        .popover(isPresented: $isPresented, arrowEdge: .trailing) {
            Text(text)
                .font(.callout)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(width: 300)
        }
    }
}

struct ModeLabel: View {
    let title: String
    let explanation: String

    var body: some View {
        HStack(spacing: 5) {
            Text(title)
            InfoLabel(text: explanation)
        }
    }
}
