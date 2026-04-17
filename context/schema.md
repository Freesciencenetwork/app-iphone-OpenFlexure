# schema

- **script**: `scripts/test_microscope_shell_online.sh`
- **args**: `[user@]host` (if no user: env `SSH_USER`, default `pi`)
- **env**: `SSH_PORT` (22), `SSH_OPTS`, `SKIP_PING`, `SKIP_SSH_EXEC`, `STRICT_HOST_KEY_CHECKING`
- **exit**: 0 online; 2 TCP failed; 3 SSH failed
- **openflexure**: `scripts/openflexure_stage.sh` + env `OPENFLEXURE_BASE` (default `http://microscope.local:5000`); cmds `test|get|move|zero|action|demo-axes`
- **diagnostics**: `scripts/openflexure_diagnose.sh`; hardware signals from `GET /api/v2/instrument/configuration` (server version, Sangaboard board/firmware, camera board); live pose `.../state/stage/position`; `inventory` parses `GET /api/v2/` WoT JSON for readproperty URLs
- **camera test**: `scripts/openflexure_camera_test.sh`; read-only: `GET /api/v2/streams/snapshot` (JPEG), `GET /api/v2/instrument/camera/lst` (PNG); writes: `POST /api/v2/actions/camera/capture/`; preview: `.../preview/start`, `.../preview/stop`
- **iOS app**: [`ios/OpenFlexureControl/OpenFluxIOS/OpenFluxIOS.xcodeproj`](ios/OpenFlexureControl/OpenFluxIOS/OpenFluxIOS.xcodeproj) — Swift in `OpenFluxIOS/OpenFluxIOS/`; docs in [`OpenFluxIOS/Docs/README.md`](ios/OpenFlexureControl/OpenFluxIOS/Docs/README.md)
