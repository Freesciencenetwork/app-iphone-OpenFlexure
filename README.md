# Mole (OpenFlexure + Pi + iOS)

Workspace layout:

- **`ios/OpenFluxIOS/`** — SwiftUI iOS app for the OpenFlexure v2 HTTP API ([`Docs/README.md`](ios/OpenFluxIOS/Docs/README.md)); Swift + assets in **`ios/OpenFluxIOS/src/`**
- **`scripts/`** — shell helpers for stage/camera/diagnostics
- **`raspberry-pi-hotspot-setup.md`** — Pi hotspot notes
- **`context/`** — session notes for this project

Open the app in Xcode: **`ios/OpenFluxIOS/OpenFluxIOS.xcodeproj`**

## Raspberry Pi OpenFlexure browser access

Current tested microscope endpoint:

```sh
http://169.254.103.118:5000/
```

Useful checks from the Mac:

```sh
curl -sS -I --connect-timeout 5 'http://169.254.103.118:5000/'
curl -sS --connect-timeout 5 'http://169.254.103.118:5000/api/v2/instrument/state'
curl -sS -m 2 'http://169.254.103.118:5000/api/v2/streams/mjpeg' -o /tmp/openflexure_mjpeg.bin -w '%{http_code} %{content_type} %{size_download}\n'
arp -a
```

What happened during debugging:

- The Pi API and web app were reachable from Terminal: `/`, `/api/v2/instrument/state`, `/api/v2/instrument/state/stage/position`, `/api/v2/streams/snapshot`, and `/api/v2/streams/mjpeg` returned valid responses.
- The browser failed on the direct link-local address with `ERR_ADDRESS_UNREACHABLE`.
- Port `80` on the Pi was closed, so the OpenFlexure web UI must be opened on port `5000`.
- A plain localhost proxy loaded the page, but the OpenFlexure API description contained absolute `http://169.254.103.118:5000/...` links, so the browser still tried to call the unreachable address.
- The proxy was updated to rewrite those absolute links to the localhost proxy URL.
- Browser cache validators caused `HTTP Error 304: NOT MODIFIED`, so the proxy now strips `If-None-Match`, `If-Modified-Since`, `Cache-Control`, and related cache headers, and returns `Cache-Control: no-store`.
- The OpenFlexure web UI disables stream preview by default when the page hostname is `localhost` or `127.0.0.1`. The proxy injects localStorage values before the Vue app starts:

```js
localStorage.setItem("disableStream", "false");
localStorage.setItem("autoGpuPreview", "false");
localStorage.setItem("trackWindow", "false");
```

Run the debuggable proxy:

```sh
python3 scripts/openflexure_browser_proxy.py --target http://169.254.103.118:5000 --port 5502 --verbose
```

Then open:

```sh
http://127.0.0.1:5502/?fresh=stream
```

If the browser still shows an old error, open that URL in a private window or hard refresh with `Cmd+Shift+R`.

The proxy can be customized:

```sh
python3 scripts/openflexure_browser_proxy.py --help
python3 scripts/openflexure_browser_proxy.py --port 5503
python3 scripts/openflexure_browser_proxy.py --no-stream-injection
```

If the direct Pi URL should work without the proxy, check macOS browser permissions:

```text
System Settings -> Privacy & Security -> Local Network
```

Enable Local Network access for the browser, then retry `http://169.254.103.118:5000/`.
