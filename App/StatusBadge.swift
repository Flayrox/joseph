import SwiftUI

enum StatusLevel {
    case active
    case error
    case neutral
}

struct StatusBadge: View {
    let title: String
    let status: String
    let level: StatusLevel

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text("\(title) : \(status)")
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color.opacity(0.14))
        )
        .foregroundStyle(color)
        .help(status)
    }

    private var color: Color {
        switch level {
        case .active: return .green
        case .error: return .red
        case .neutral: return .gray
        }
    }

    /// Derives a level from the raw status string of a manager.
    static func level(for status: String) -> StatusLevel {
        let value = status.lowercased()
        if value.contains("enabled")
            || value.contains("connected")
            || value.contains("reachable")
            || value.contains("active") {
            return .active
        }
        if value.contains("error")
            || value.contains("failed")
            || value.contains("restore required")
            || value.contains("exited")
            || value.contains("unavailable")
            || value.contains("no response")
            || value.contains("probe failed") {
            return .error
        }
        return .neutral
    }
}