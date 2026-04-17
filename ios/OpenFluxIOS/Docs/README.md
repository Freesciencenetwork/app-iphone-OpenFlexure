# OpenFluxIOS (OpenFlexure SwiftUI)

Neon-style iOS app for an [OpenFlexure](https://openflexure.org) microscope **v2 HTTP API** on your LAN: stage moves, JPEG live preview (`/api/v2/streams/snapshot`), still capture, optional GPU preview after connect.

## Requirements

- **Xcode 15+** (iOS **17**+ recommended for `@Observable` / `@Bindable`).
- Device or simulator on the **same network** as the Pi (e.g. `http://microscope.local:5000`).

## This folder layout

- **`OpenFluxIOS.xcodeproj`** — open this in Xcode.
- **`App/`** — Swift sources and `Assets.xcassets` (Xcode **File System Synchronized** group: new `.swift` files here are picked up automatically).
- **`Docs/`** — this README, [`API_PATHS.md`](API_PATHS.md), [`ATS-Info-fragment.md`](ATS-Info-fragment.md).

## App Transport Security (local HTTP)

OpenFlexure uses **cleartext HTTP** on the LAN. In the **OpenFluxIOS** target → **Info** → add:

| Key | Type | Value |
|-----|------|--------|
| **App Transport Security Settings** (`NSAppTransportSecurity`) | Dictionary | |
| ↳ **Allows Local Networking** (`NSAllowsLocalNetworking`) | Boolean | **YES** |

See [`Docs/ATS-Info-fragment.md`](ATS-Info-fragment.md) for the plist fragment.

## Run

1. Open **`OpenFluxIOS.xcodeproj`**.
2. Build and run; set the microscope base URL via the **gear** icon (default `http://microscope.local:5000`).
3. **Stage**: D-pad / focus → `POST …/actions/stage/move/`.
4. **Photo** → `POST …/actions/camera/capture/` (`ios_capture_<timestamp>`).
5. Optional **GPU preview** after connect in Settings.

## Shell helpers (repo root)

Same API as the bash tools under [`../../../scripts`](../../../scripts) (e.g. `openflexure_stage.sh`, `openflexure_camera_test.sh`).

## Reference API

`http://<host>:5000/api/v2/docs/swagger-ui`

## Assets (optional)

Design reference: `../../../assets/image-256ff73d-c754-4511-8bd3-850a6895a940.png` — add to **Asset Catalog** if desired (create `assets/` at repo root if you use it).

## Entry point

`@main` is **`OpenFluxIOSApp`** in `App/OpenFluxIOSApp.swift`; it hosts **`MainMicroscopeView`**.
