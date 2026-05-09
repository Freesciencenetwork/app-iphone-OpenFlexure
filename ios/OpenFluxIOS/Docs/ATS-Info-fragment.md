# App Transport Security (local HTTP)

Merge this into your app **Info** (or an Info.plist) so `http://` to your Pi on the LAN is allowed:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSLocalNetworkUsageDescription</key>
	<string>OpenFlux connects to the OpenFlexure microscope on the local network for stage control and camera preview.</string>
	<key>NSAppTransportSecurity</key>
	<dict>
		<key>NSAllowsLocalNetworking</key>
		<true/>
	</dict>
</dict>
</plist>
```

In Xcode: target → **Info** → add **Privacy - Local Network Usage Description**, then add **App Transport Security Settings** → **Allows Local Networking** = YES.
