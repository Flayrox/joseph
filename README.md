# joseph

**J**ourney **O**rchestrator for **S**eamless **E**xecution, **P**ower & **H**otspot.

joseph is a native macOS menu-bar utility for keeping a Mac available during travel and supervising long-running local workflows.

## What is an agent?

An agent is any local executable that joseph launches and supervises: an AI command-line worker, shell script, development server, Docker wrapper, build process, or another long-running program.

When an agent is launched, joseph can:

- keep its lifecycle visible;
- capture bounded stdout and stderr;
- show whether it is running, finished, or interrupted;
- stop the process;
- hold the native keep-awake assertion while work is active.

No remote AI service is included automatically. joseph only runs the executable and arguments selected by the user.

## Power modes

Each mode has its own toggle and information icon in the app. They are independent: enabling one does not automatically enable the others.

### Mode Voyage — assertion native

Uses macOS IOKit power assertions directly. It prevents idle/system sleep while enabled, without changing persistent `pmset` preferences. This is the preferred lightweight mode, but macOS and hardware still control thermal and clamshell safety.

### pmset — bloquer la veille

Uses administrator-authorized `pmset` commands to change sleep settings while enabled. Before changing anything, joseph snapshots the battery and charger values to:

```text
~/Library/Application Support/joseph/pmset-snapshot.json
```

Disabling the toggle restores the exact snapshot. If joseph is interrupted, the snapshot remains available for restoration on the next launch. This mode is intentionally powerful and should not be used in a closed bag without thermal safeguards.

### caffeinate — garder l’écran actif

Starts only joseph’s owned `caffeinate -d` process. It prevents display idle sleep while the toggle is enabled. It does not alter persistent system preferences and is stopped when disabled.

### Heartbeat — ping toutes les 15 s

Starts only joseph’s owned `ping -i 15 1.1.1.1` process. It is a basic connectivity heartbeat, not a guarantee that an iPhone hotspot or carrier connection stays awake. It is stopped when disabled.

The four controls are independent. Enabling one does not silently enable the others.

## Branding assets

- `Resources/logo_outline.png`: transparent logo, used without a background in the menu-bar panel.
- `Resources/logo_fill.jpg`: filled logo, used inside a background in the agent-launch window.

## Status

Early development. Network routing, thermal telemetry, and remote GUI control are intentionally not enabled yet. They require hardware validation and additional macOS security analysis.

## Development

The project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
xcodegen generate
open joseph.xcodeproj
```

Build and test from Xcode or with:

```sh
xcodebuild test \
  -project joseph.xcodeproj \
  -scheme joseph \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO
```

The deployment target is macOS 14 or newer.

## Safety model

- Power assertions are released when disabled and when their owner is destroyed.
- pmset changes are snapshot-backed and restored on normal deactivation.
- Process launch failures do not change power state.
- Automatic network routing is not performed.
- Caffeinate and heartbeat processes are owned and terminated by joseph.
- Keep these controls disabled during thermal or battery-critical testing.
- joseph does not claim that a power assertion guarantees clamshell operation on every Mac model or macOS release.

## Roadmap

1. Thermal guard with hardware-specific providers and safe fallback.
2. Process groups, cancellation, and log rotation.
3. Read-only USB/iPhone interface diagnostics.
4. Opt-in network policy with rollback.
5. Signed/notarized release packaging.
6. Remote GUI research as a separate final phase.

## License

MIT. See [LICENSE](LICENSE).
