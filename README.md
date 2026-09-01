# JOSEPH

**J**ourney **O**rchestrator for **S**eamless **E**xecution, **P**ower & **H**otspot.

JOSEPH is a native macOS menu-bar utility for keeping a Mac available during travel and supervising long-running local workflows.

## Status

Early development. The current foundation provides:

- macOS menu-bar UI;
- explicit, idempotent IOKit power assertions;
- independent opt-in toggles for `pmset`, `caffeinate`, and the heartbeat process;
- exact `pmset` snapshot persistence and restoration when the pmset toggle is disabled;
- process lifecycle supervision with bounded stdout/stderr capture;
- read-only network path diagnostics;
- persistent runtime logging under `~/.joseph/logs/`.

Network routing, thermal telemetry, and remote GUI control are intentionally not enabled yet. They require hardware validation and additional macOS security analysis.

## Development

The project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
xcodegen generate
open joseph.xcodeproj
```

Build and test from Xcode or with `xcodebuild` using the generated project. The deployment target is macOS 14 or newer.

## Safety model

- Power assertions are released when explicitly disabled and when their owner is destroyed.
- A failed secondary assertion does not hide the primary failure.
- Process launch failures are reported without changing power state.
- Automatic network configuration is not performed by default.
- The pmset toggle is opt-in, requests administrator authorization through macOS, and restores the saved battery/charger values when disabled.
- The caffeinate and heartbeat toggles do not require administrator privileges and terminate their owned processes when disabled.
- Keep these controls disabled during thermal or battery-critical testing.
- JOSEPH does not claim that a power assertion guarantees clamshell operation on every Mac model or macOS release.

## Roadmap

1. Testable power assertion state machine and UI polish.
2. Process groups, cancellation, bounded output, and log rotation.
3. Read-only network interface and path diagnostics.
4. Opt-in network policy with rollback.
5. Hardware-specific thermal safety providers.
6. Remote GUI research as a separate final phase.

## License

MIT. See [LICENSE](LICENSE).
