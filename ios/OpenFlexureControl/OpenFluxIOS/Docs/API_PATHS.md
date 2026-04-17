# OpenFlexure v2 API paths used in this repo

Prefix every path with your base URL, e.g. `http://microscope.local:5000`.

Trailing slashes: this repo uses **trailing slashes on POST action URLs** where noted; your server may accept both forms.

## Documentation and discovery

| Method | Path | Where |
|--------|------|--------|
| GET | `/api/v2/` | [`scripts/openflexure_diagnose.sh`](../../../../scripts/openflexure_diagnose.sh) `inventory` (Thing Description JSON) |
| GET | `/api/v2/docs/swagger-ui` | [`scripts/openflexure_camera_test.sh`](../../../../scripts/openflexure_camera_test.sh) `probe`; README |
| GET | `/api/v2/docs/openapi.yaml` | [`scripts/openflexure_diagnose.sh`](../../../../scripts/openflexure_diagnose.sh) `discover` |

## Instrument (state, configuration, stage, camera)

| Method | Path | Where |
|--------|------|--------|
| GET | `/api/v2/instrument/state` | diagnose `check`; Swift [`OpenFlexureClient.ping`](../OpenFluxIOS/OpenFlexureClient.swift) |
| GET | `/api/v2/instrument/state/stage` | diagnose `discover` |
| GET | `/api/v2/instrument/state/stage/position` | diagnose `check`; stage `test`; Swift stage position |
| GET | `/api/v2/instrument/state/camera` | diagnose `discover`; camera `probe` |
| GET | `/api/v2/instrument/configuration` | diagnose `check` / `discover`; camera `check` / `probe` |
| GET | `/api/v2/instrument/settings` | diagnose `discover`; camera `probe` |
| GET | `/api/v2/instrument/stage/type` | stage `test`; diagnose `check` |
| GET | `/api/v2/instrument/camera/lst` | camera `check` / `probe` (PNG tile) |

`openflexure_stage.sh get <path>` can **GET** any path under `/api/v2/<path>` (e.g. `instrument/state`).

## Streams

| Method | Path | Where |
|--------|------|--------|
| GET | `/api/v2/streams/snapshot` | camera `check` / `snapshot` / `probe`; Swift preview loop |
| GET | `/api/v2/streams/mjpeg` | camera `probe` only (not implemented in Swift v1) |

## Captures

| Method | Path | Where |
|--------|------|--------|
| GET | `/api/v2/captures` | diagnose `discover` / Python `check` |

## Actions (list and by id)

| Method | Path | Where |
|--------|------|--------|
| GET | `/api/v2/actions/` | diagnose `check` / `discover` |
| GET | `/api/v2/actions/{id}` | [`ActionPoll.swift`](../OpenFluxIOS/ActionPoll.swift); stage `action`; camera `wait_action` (bash) |

## Stage actions

| Method | Path | Where |
|--------|------|--------|
| POST | `/api/v2/actions/stage/move/` | stage `move` / `demo-axes`; Swift moves |
| POST | `/api/v2/actions/stage/zero/` | stage `zero`; Swift settings “Zero stage” |

## Camera actions

| Method | Path | Where |
|--------|------|--------|
| POST | `/api/v2/actions/camera/capture/` | camera `capture` / `all`; Swift Photo |
| POST | `/api/v2/actions/camera/preview/start/` | camera `preview-start`; Swift optional GPU preview |
| POST | `/api/v2/actions/camera/preview/stop/` | camera `preview-stop`; Swift `onDisappear` |

### On server OpenAPI but not wired in this repo

| Method | Path | Note |
|--------|------|------|
| POST | `/api/v2/actions/camera/ram-capture/` | Listed in upstream OpenAPI; use Swagger on your Pi to confirm body |

## Extensions (diagnostics probe list)

| Method | Path | Where |
|--------|------|--------|
| GET | `/api/v2/extensions/org.openflexure.autostorage/location` | diagnose `discover` / `check` |
| GET | `/api/v2/extensions/org.openflexure.autostorage/list-locations` | diagnose `discover` |
| GET | `/api/v2/extensions/org.openflexure.zipbuilder/get` | diagnose `discover` |
| GET | `/api/v2/extensions/org.openflexure.camera-stage-mapping/get_calibration` | diagnose `discover` |

## Full set (deduplicated, copy-paste)

```
GET  /api/v2/
GET  /api/v2/actions/
GET  /api/v2/actions/{id}
GET  /api/v2/captures
GET  /api/v2/docs/openapi.yaml
GET  /api/v2/docs/swagger-ui
GET  /api/v2/extensions/org.openflexure.autostorage/list-locations
GET  /api/v2/extensions/org.openflexure.autostorage/location
GET  /api/v2/extensions/org.openflexure.camera-stage-mapping/get_calibration
GET  /api/v2/extensions/org.openflexure.zipbuilder/get
GET  /api/v2/instrument/camera/lst
GET  /api/v2/instrument/configuration
GET  /api/v2/instrument/settings
GET  /api/v2/instrument/stage/type
GET  /api/v2/instrument/state
GET  /api/v2/instrument/state/camera
GET  /api/v2/instrument/state/stage
GET  /api/v2/instrument/state/stage/position
GET  /api/v2/streams/mjpeg
GET  /api/v2/streams/snapshot
POST /api/v2/actions/camera/capture/
POST /api/v2/actions/camera/preview/start/
POST /api/v2/actions/camera/preview/stop/
POST /api/v2/actions/camera/ram-capture/
POST /api/v2/actions/stage/move/
POST /api/v2/actions/stage/zero/
```

Additional routes (PUT, other extensions, calibration, autofocus, etc.) exist on your microscope; **`GET /api/v2/docs/openapi.yaml`** or **`GET /api/v2/`** is authoritative for that build.
