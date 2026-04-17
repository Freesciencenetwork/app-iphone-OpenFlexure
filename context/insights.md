# insights

- **2026-04-17**: Inner sources folder renamed **`App/`** (was `OpenFluxIOS/` inside `ios/OpenFluxIOS/`) so paths are not `OpenFluxIOS/OpenFluxIOS`.
- **2026-04-17**: `ios/OpenFlexureControl/` was a useless extra folder (only child `OpenFluxIOS`); flattened to **`ios/OpenFluxIOS/`**. Removed stray `OpenFluxIOS/File.txt` (accidental path paste).
- **2026-04-17**: Git root is **Mole**; `origin` = https://github.com/Freesciencenetwork/app-iphone-microscope.git (repo is monorepo: `ios/`, `scripts/`, `context/`, Pi markdown). Old iOS-only history on `main` was force-replaced by root commit `55fed76`.
- **2026-04-16**: Public “OpenFlux microscope” hits are mostly unrelated (AI client, FLUX image model, metabolic OpenFLUX). Microscope + shell usually = SSH to embedded Linux (often `pi@`).
- **2026-04-16**: `OpenFluxIOS` git: avoid staging new small plist next to `git rm xcuserdata`—Git treated it as rename; fixed by ATS doc as `Docs/ATS-Info-fragment.md`. Pushed to https://github.com/Freesciencenetwork/app-iphone-microscope.git
