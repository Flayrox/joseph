import SwiftUI

struct SafetySettingsView: View {
    @ObservedObject var controller: PowerSafetyController

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text("Sécurité anti-veille")
                    .font(.subheadline.weight(.semibold))
                InfoLabel(text: "La durée maximale coupe automatiquement le Mode Voyage après le délai choisi. Le seuil de batterie coupe également ce mode si la batterie passe sous le seuil. Ces protections évitent de laisser le Mac éveillé par oubli.")
            }

            HStack {
                Text("Durée maximale")
                Spacer()
                Picker("Durée maximale", selection: Binding(
                    get: { controller.settings.maximumDurationMinutes },
                    set: { update(maximumDurationMinutes: $0) }
                )) {
                    Text("30 min").tag(30)
                    Text("1 h").tag(60)
                    Text("2 h").tag(120)
                    Text("4 h").tag(240)
                    Text("8 h").tag(480)
                }
                .labelsHidden()
            }

            HStack {
                Text("Batterie minimum")
                Spacer()
                Picker("Batterie minimum", selection: Binding(
                    get: { controller.settings.minimumBatteryPercent },
                    set: { update(minimumBatteryPercent: $0) }
                )) {
                    Text("0 %").tag(0)
                    Text("10 %").tag(10)
                    Text("20 %").tag(20)
                    Text("30 %").tag(30)
                    Text("50 %").tag(50)
                }
                .labelsHidden()
            }

            Toggle("Exiger le chargeur", isOn: Binding(
                get: { controller.settings.requirePowerAdapter },
                set: { update(requirePowerAdapter: $0) }
            ))
            .help("Refuse et coupe le Mode Voyage lorsque le Mac n’est pas branché au secteur.")

            if let remaining = controller.remainingSeconds {
                Text("Mode Voyage restant : \(Self.format(remaining))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 2)
    }

    private func update(maximumDurationMinutes: Int? = nil, minimumBatteryPercent: Int? = nil, requirePowerAdapter: Bool? = nil) {
        var settings = controller.settings
        if let maximumDurationMinutes { settings.maximumDurationMinutes = maximumDurationMinutes }
        if let minimumBatteryPercent { settings.minimumBatteryPercent = minimumBatteryPercent }
        if let requirePowerAdapter { settings.requirePowerAdapter = requirePowerAdapter }
        controller.update(settings)
    }

    private static func format(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 { return String(format: "%dh %02dmin", hours, minutes) }
        return String(format: "%dmin %02ds", minutes, secs)
    }
}
