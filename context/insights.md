# insights

- **2026-04-17**: Swift sources folder **`src/`** under `ios/OpenFluxIOS/` (was `App/`, before that duplicate `OpenFluxIOS/`).
- **2026-04-17**: `ios/OpenFlexureControl/` was a useless extra folder (only child `OpenFluxIOS`); flattened to **`ios/OpenFluxIOS/`**. Removed stray `OpenFluxIOS/File.txt` (accidental path paste).
- **2026-04-17**: Git root is **Mole**; `origin` = https://github.com/Freesciencenetwork/app-iphone-microscope.git (repo is monorepo: `ios/`, `scripts/`, `context/`, Pi markdown). Old iOS-only history on `main` was force-replaced by root commit `55fed76`.
- **2026-04-16**: Public “OpenFlux microscope” hits are mostly unrelated (AI client, FLUX image model, metabolic OpenFLUX). Microscope + shell usually = SSH to embedded Linux (often `pi@`).
- **2026-04-16**: `OpenFluxIOS` git: avoid staging new small plist next to `git rm xcuserdata`—Git treated it as rename; fixed by ATS doc as `Docs/ATS-Info-fragment.md`. Pushed to https://github.com/Freesciencenetwork/app-iphone-microscope.git
- **2026-05-09**: `xcodebuild` on this Mac: CoreSimulator “out of date” (1051.49.0 vs 1051.50.0) — simulator support disabled until OS/Xcode alignment.
- **2026-05-09**: From dev machine: `microscope.local` did not resolve (`curl` / `ping` unknown host) — mDNS or network path may differ; use `OPENFLEXURE_BASE=http://<pi-ip>:5000` for tests.
- **2026-05-09**: Stage limits enforced client-side: **XY ±100**, **Z ±20** via `clampedRelativeDeltas` (`MicroscopeRuntime`); manual `move` + mosaic relative steps; settings steppers X/Y `1…100`, Z `1…20`; mosaic step X/Y `1…100`. Absolute mosaic return-to-start unchanged.
