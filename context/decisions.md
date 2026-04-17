# decisions

- **2026-04-16**: Bash + `ssh -o BatchMode=yes` for “online” = TCP/22 open + key-based (or agent) non-interactive shell; no vendor-specific API (OpenFlux name unclear; OpenFlexure uses SSH on Pi).
- **2026-04-16**: Health signals from HTTP v2: `instrument/configuration` (app version, stage board/firmware, camera board), `instrument/state` + nested `stage/position`, `actions/` list for stuck failures, WoT root `/api/v2/` for discoverable GET hrefs; empty `state.camera` not warned by default.
