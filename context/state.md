# state (2026-05-09)

- **active**: run app from Xcode (project opened).
- **last done**: Stage axis limits in app: XY ±100, Z ±20 — `clampedRelativeDeltas` in `MicroscopeRuntime.swift`; settings/mosaic steppers capped (`ConnectionSettingsView`, `CapturePlannerSheet`).
- **prior**: `open ios/OpenFluxIOS/OpenFluxIOS.xcodeproj`; CLI `xcodebuild` may fail (signing + Simulator).
- **blockers**:
  - **Signing**: target needs **Team** in Signing & Capabilities (CLI: no DEVELOPMENT_TEAM).
  - **Simulator**: CoreSimulator framework mismatch (1051.49.0 vs 1051.50.0) — update macOS/Xcode or Command Line Tools per Xcode recovery text.
- **next**: In Xcode: pick team → choose simulator or device → ⌘R. Set microscope URL in-app (gear); see `ios/OpenFluxIOS/Docs/README.md`.
- **note**: This repo has **no HTTP server** to start; OpenFlexure API runs on the **Pi** (e.g. `ofm start` on Raspbian-OpenFlexure — see openflexure.org docs).
