# Qeno for iPhone

One app for everything a user does on the phone: setup (Developer Mode, on-device pairing, UI
Automation, the loopback, the first-session passcode), starting and stopping a session, the Live
Activity with Approve/Deny for sensitive actions, the MCP address for each client (text, QR, copy),
and a Debug tab (the former Qeno Probe). Native SwiftUI on the iOS 26 SDK with Liquid Glass.

Qeno automates the phone in its own process: it opens the XCTest automation session itself
(`Qeno/Native/InProcess.m`, answered to PokiCore by `Qeno/Runtime/InProcessWDA.swift`), so Qeno is
the only app to install. The older Runner path (WebDriverAgent as a second bundle, built by
`.github/workflows/ios-runner.yml`; `docs/single-bundle.md` is the earlier study) stays in the code
and is chosen per launch with `-automationPath runner`.

## Layout

| Path | What |
|---|---|
| `Qeno/App` | App entry (Chat and Voice pages), status words and issues, all steps, the app model (on/off, runner sleep and wake, events, approvals, pairing, setup steps) |
| `Qeno/Setup` | Setup, one guided page with live checks |
| `Qeno/Loopback` | Local VPN configuration and status, live developer-service checks, external VPN choices |
| `Qeno/Activity` | Live Activity controller (state, steps, thumbnail in the App Group) |
| `Qeno/Connect` | Relay identity (Ed25519 key, label, connector secrets in the keychain), MCP address with QR |
| `Qeno/Runtime` | PokiCore and PokiLauncher glue, background keep-alive (location, then silent audio) |
| `Qeno/Voice` | Talk to Qeno: an OpenAI Realtime session over WebRTC, the calls it asks for, test runs |
| `Qeno/Debug` | 10.7.0.1 checks, the background hold test, the Live Activity preview |
| `Shared` | Live Activity attributes and views, the Approve/Deny/Stop App Intents (app and widget) |
| `PokiWidgets` | The Live Activity widget |
| `PokiTunnel` | Local-only IPv4 TCP packet tunnel; no server, DNS or internet default route |

PokiCore (Swift, `native/ios/PokiCore`) and PokiLauncher (Rust with a C ABI, `native/launcher`) are described in `docs/ios-core.md`. Qeno has no default relay: the person deploys their own (`deploy/cf-relay/DEPLOY.md`) and enters its address in the Connect tab.

## Build

GitHub Actions (`.github/workflows/ios-app.yml`) builds `Qeno-unsigned.ipa` on demand, for
`ios-v*` release tags and for `ios-alpha-*` / `ios-prealpha-*` tags (see `docs/release-channels.md`), runs it on the iOS Simulator and uploads a screenshot of every screen in light and
dark mode (artifact `simulator-smoke`, folder `shots`). Locally on a Mac with Xcode 26 or later:

```sh
native/ios-app/scripts/make-assets.sh
xcodegen generate --spec native/ios-app/project.yml
open native/ios-app/Qeno.xcodeproj
```

`native/ios-app/scripts/app-tests.sh SIMULATOR_UDID` builds `PokiTests` and runs it inside Qeno on a booted simulator (the in-process transport's clipboard and session answers).

`-pokiScreen home|setup|connect|debug|activity|steps|status|connector|details|model|voice` opens that screen at launch (home is the chat, setup its full-screen flow, connect the Settings sheet, debug Diagnostics inside it, details Qeno's details, steps its history); `-pokiChat empty|working|approved` and `-pokiVoice ready|listening|working` show the ESP-171 boards' sample chat and voice faces; `-pokiSetupStep N` opens setup at step N, and `-pokiSample B|C` fills the status, history and Live Activity with sample steps and an approval, and `-pokiSample PIN` shows a sample pairing code, for screenshots only; on a simulator `-pokiLoopback cellular` forces the cellular-only loopback hint, `-pokiLoopback working` a loopback that answers, and `-pokiSigningDays 1` a signing that ends in a day.

Qeno is in English and Simplified Chinese and follows the iPhone's language. The app's screens use the String Catalog `Shared/Localizable.xcstrings`, the Live Activity its own table `Shared/LiveActivity.xcstrings` (see `Shared/ActivityWords.swift`), and the permission prompts `Qeno/InfoPlist.xcstrings`. Qeno's own status words stay in English inside the app (the code compares them and the agent reads them) and are looked up where they reach the screen; the launcher's fix sentences have entries too. Steps an agent reports, logs and diagnostics output stay as they come. Add `-AppleLanguages '(zh-Hans)'` to a launch to see Chinese without changing the simulator's language.

## How it runs

- Qeno stays on once turned on, and turns on again at launch. Turning on asks for everything at once:
  with Qeno in front and no automation since the iPhone restarted, Qeno first says iOS will ask for
  the passcode, and Continue opens the session as soon as the launcher is ready, which brings up iOS's
  passcode screen. Once the launcher has mounted the
  disk image, Qeno opens its automation session (the log says `in-process session ready`), so the
  first look does not wait for it. The session, and with it iOS's automation banner, is closed after
  the idle time (default 60 s), from Stop on the Live Activity or in Qeno, and when Qeno is turned off;
  the next agent request opens a new one (a few seconds; iOS asks for the passcode only once per
  boot). If it cannot be opened, an agent's call answers at once with the reason, and the next call,
  Qeno coming to the front, or an agent connecting tries again. An open that has not answered in 5 s
  is waiting on iOS's passcode prompt (after Qeno restarts, and 8 hours after the passcode was last
  entered): the Live Activity shows Passcode for automation, Qeno's home asks the owner, and the agent
  reads that only the owner can enter it. When iOS gives up, after about a minute, the call fails with
  that reason. A passcode screen that was cancelled or missed is not opened again, by Qeno or by an
  agent's call, until the owner turns Qeno on again. Opens go through one gate: one at a time, and
  none from the background before the boot's first automation.
- Nothing listens on a port: PokiCore's requests are answered inside Qeno.
- The built-in local connection dials itself again when it fails or drops while Qeno is on: 1, 2, 4, 8,
  16, 30, 30, 30 s, then it stops until the owner taps Enable Local Connection in Setup. Opening Qeno
  dials nothing. It does not dial when the owner ended it (Turn off, Disconnect, Settings > VPN), when
  another VPN took the packet tunnel, or when another VPN is detected at the time of a try: Qeno says so and
  stops. Detection is best effort: a VPN that sets no proxy, such as Tailscale, may not be detected. The automation then comes back by the loopback's own recovery. An external
  connection is never touched.
- Runner path only (`-automationPath runner`): the runner, and with it the banner, starts only when
  an agent asks, and stops after the idle time (default 60 s), from Stop on the Live Activity or in
  Qeno, or when Qeno is closed. Only Qeno starts the runner; opened by hand, Qeno Runner starts no
  test (PokiRunnerHost, `native/ios-runner/host`) and sends the person to Qeno. While it runs, it
  answers on port 8100 to any device on the same network, with no credentials and without Qeno's
  approvals (`native/ios-runner/README.md`).
- The Live Activity starts from the foreground, because iOS does not allow it from the background:
  when Qeno turns on, when pairing starts, and when a setup step opens Settings.

## Voice

Voice (the waveform button beside the gear on Home, a sheet) talks to OpenAI's Realtime API (`gpt-realtime-2.1`) over WebRTC: the microphone is the
audio track, Qeno's voice plays on the speaker, and events travel on the `oai-events` data channel.
The phone never holds an OpenAI key. The voice bridge on the person's Mac (`bin/voice-bridge.mjs`)
keeps the key and gives the phone a client secret that expires after 60 seconds:

1. Create an API key at platform.openai.com (API keys). Realtime audio is billed to that account per
   token; each test turn reports the tokens it used.
2. Keep it in the keychain, and read it from there, so it never lands in your shell history:

   ```sh
   security add-generic-password -a "$USER" -s openai-api-key -w    # asks for the key
   export OPENAI_API_KEY="$(security find-generic-password -s openai-api-key -w)"
   ```

3. Start Qeno MCP first (`npm start`, see [docs/install.md](../../docs/install.md)); the bridge stops at
   once with "Local Qeno MCP is not running" without it. Then, with the same state directory:

   ```sh
   POKI_MCP_STATE_DIR=... node bin/voice-bridge.mjs --device <iPhone id>
   ```

The bridge listens on every network interface (`--host 0.0.0.0`), because the phone reaches it over
the local network, in plain HTTP. Anyone who learns its address, which carries the secret, can open
sessions on your OpenAI key and move the phone through your Mac. Run it only on a network you trust,
and pass `--host <this Mac's LAN address>` to keep it off other interfaces (for example a VPN).

Enter `http://<Mac>:47830/voice/<secret>` in Voice (the secret is in `voice-bridge.json` in the
state directory). `get_ios_version` is answered on the phone;
the bridge runs the tools that move the phone (`open_settings`, `read_screen`, `open_app`, `tap_text`,
`go_home`) through the Mac's Qeno MCP.

- Each function call runs once, keyed by its `call_id`, in the app and again in the bridge.
- `tap_text` is held by Qeno's approvals, like an agent's `do`: the bridge first says what it would tap
  and in which app, without tapping; the phone checks that with PokiCore's rules (payments, deleting,
  sending messages, calls) and, when they ask for it, waits up to two minutes for Allow (in the Dynamic Island, on the Live
  Activity or from the notification). Only then does the bridge tap that element, matched exactly, in that app.
- A dropped connection sends nothing again. A call outlives the session that asked for it; the next
  session is told how it ended instead of asking for it again.
- Stop talking (or speaking over Qeno) cancels the reply, never the step running on the phone.
- Once an answer has played and no step it asked for is running, the conversation waits 8 s for the
  person to go on in the same session. After 8 s of silence it ends and lets go of the microphone, so
  iOS's orange dot goes off; a conversation opened with nothing said ends the same way. A
  conversation opened within 5 minutes of the last end is told up to 6 lines said in that last
  conversation with something said in it (a conversation nobody spoke in changes nothing), from
  memory (the chat keeps its own copy as before). In the background Qeno stops listening at once, also
  while connecting, unless a step is running or its answer is still to be said (the step brings another
  app to the front); that conversation ends as soon as that is said.
  A conversation never waits for the server for ever: when it owes something (the end of the person's
  speech, an answer, the end of the audio) and the server says nothing for 60 s, or 30 s after Qeno went
  to the background, it ends. A step that is running is not counted; its result starts a new wait.
- A `qeno://voice` link, from a web page or another app, only opens Voice: a link never
  changes the bridge and never turns on the microphone. The person enters the address and taps Talk
  to Qeno.
- Development builds only: the launch argument `-qenoVoiceLink "qeno://voice?bridge=<address>&test=1-20"`
  runs recorded utterances from a bridge started with `--test-dir`, silently: the speech goes over
  the data channel instead of the microphone, and Qeno's voice is muted. Release builds have no test
  runs.

## Signing and entitlements

| Entitlement | Needed for | Notes |
|---|---|---|
| App Groups `group.com.owaiken.qeno` | Live Activity thumbnail, approvals between widget and app | Signing tools rewrite group ids per Apple ID; that works as long as both targets get the same rewritten group. |
| Network Extensions `packet-tunnel-provider` | Built-in local connection | Required in both Qeno and PokiTunnel, with a matching provisioning profile for each bundle. A wildcard profile is insufficient. |

Which build to sign depends on the Apple account:

| Apple account | Build | Local connection | Signing |
|---|---|---|---|
| Paid Apple Developer Program team | `Qeno-unsigned.ipa` (`project.yml`) | Built-in, or an external VPN app | App IDs for Qeno, `.widgets` and `.tunnel`; the App Group on Qeno and `.widgets`; Network Extensions (packet tunnel) on Qeno and `.tunnel`; a development or ad-hoc profile for each of the three. |
| Free Apple ID (Personal Team) | `Qeno-external-unsigned.ipa` (`project-external.yml`) | An external VPN app or LocalDevVPN only | The App Group on Qeno and `.widgets` (signing tools rewrite it per Apple ID). Apps signed this way expire after 7 days, and only 3 can be installed at a time; Qeno uses one (two with Qeno Runner on the Runner path). |

On the Runner path, sign Qeno Runner with the same account as Qeno in both cases.

The default `project.yml` builds Qeno with its local VPN. Use signing that supports Network
Extensions (including properly provisioned paid-team development/ad-hoc distribution). Free Personal
Team signing cannot provision this capability. Re-signing must preserve the entitlement in both the
app and its extension. CI includes the generated entitlements in `Qeno-signing.zip`.

For a team that does not own the default identifiers, set `POKI_BUNDLE_ID`, `POKI_APP_GROUP` and
optionally `POKI_DISPLAY_NAME` in Xcode or the `xcodebuild` invocation. Register the App Group and
associate it with both the app and widget identifiers in the developer portal before provisioning.
The app and widget read that same group from their built Info.plist; approval notifications are
namespaced to it. Do not reuse another app's group just to make signing pass.

`project-external.yml` builds the same app without the tunnel or its Network Extension entitlement:

```sh
xcodegen generate --spec native/ios-app/project-external.yml
open native/ios-app/PokiExternal.xcodeproj
```

CI produces `Qeno-unsigned.ipa` and `Qeno-external-unsigned.ipa`. Choose one; on the Runner path,
also install Qeno Runner with the same signing. The external build retains the App Group requirement for approvals and
thumbnails; it does not solve other free-account signing restrictions.

## Loopback choices

Setup initially offers an installed supported VPN before the built-in option. The user selects the
connection explicitly; an existing service response alone does not finish the setup step.

- **Karing**: keep its VPN connected, set TUN > Loopback address to `10.7.0.1`, and use **External
  app** in Qeno. Qeno's VPN stays off, so Karing continues to own the single packet tunnel. See the
  [maintainer's iOS support record](https://github.com/KaringX/karing/issues/899); verify the installed
  version and the developer-service check before continuing.
- **Built-in (default)**: Setup > Connect to this iPhone > Enable local connection. Approve iOS's
  VPN configuration prompt. Qeno reflects only IPv4 TCP to `10.7.0.1/32`; normal internet routes and
  DNS are unchanged. The connection may displace another packet-tunnel VPN. Qeno does not silently
  change an external VPN configuration or start its local VPN merely because the app opened. While
  Qeno is on, its own tunnel is dialled again after a failure (see above), and stops when it detects another VPN (best effort, as above).
- **Proxy app**: Surge (module, `surge:///install-module?url=`), Loon (plugin,
  `loon://import?plugin=`), Shadowrocket (its "Include route 10.7.0.1/32" toggle), sing-box (one
  line in the tun inbound), and, as users report rather than as their makers document, Stash and
  Clash Mi (`loopback-address` in the tun section) and Quantumult X (`reflected_routes` in
  `[general]`); those entries say so on the page. Files and sources in `deploy/proxy-modules/`,
  served from the fork's raw GitHub URL for now (`ProxyApps.modulesBase`). Each row's tag is live:
  the chosen app reads Working while 10.7.0.1 answers and Not Answering while it does not.
- **External build without a proxy app**: LocalDevVPN (App Store). This is an additional app and
  must be tested with the installed iOS version. It may displace another packet-tunnel VPN.

The setup step completes only when a TCP connection to the phone's RemotePairing or lockdown
service succeeds. Selecting an app, saving a profile or a VPN's Connected label alone never completes
it. Built-in VPN transport cannot be validated in the Simulator. See [the design and acceptance
checks](../../docs/ios-loopback.md).

## iPad, iPhone Duo: Qeno beside the app it drives

Qeno builds for iPhone and iPad (every orientation on iPad; the iPhone Duo's inner display is
regular width, laid out like an iPad). The point of the larger screens is Qeno, or any agent chat,
beside the app being driven: on the Duo's inner display in landscape iOS 27.1 puts two apps side by
side (a fixed 50/50 Split View, with app pairs); on iPadOS 26 apps are resizable windows, with
Stage Manager. The in-process path keys on the driven app's frame, not on either layout: with
several apps on screen Qeno's own process is never the front app, and when the front app's frame
is smaller than the screen (its half of the Duo, its window on the iPad) that frame is the viewport
(`PKInProcess.viewport`): the element tree's frames and the screenshot are relative to it,
`/wda/screen` reports its size, and touches are moved back onto the screen. An app that fills the
screen has no viewport. Not yet checked in the gym on an iPad simulator with two windows.

## Pairing by iOS version, and the pairing file's life

Pairing on the phone itself (Settings > Privacy & Security > Developer Mode > Pair with Qeno) exists
from iOS 27 (`SetupStep.onDevicePairing`). On earlier versions the pairing page shows the other way
only: pair from a computer with Qeno Setup (or pymobiledevice3, jitterbugpair, StikPair), then send
the file to the phone. Qeno takes a pairing file three ways besides Import Pairing File:

- A file opened with Qeno from AirDrop or Files (`CFBundleDocumentTypes`: property lists and
  `.mobiledevicepairing`).
- `qeno://pairing?url=http://<computer on the LAN>:<port>/<file>&sha256=<hex>`: Qeno fetches the
  file over the local network and checks the digest; Qeno Setup shows this link as a code for the
  Camera. `qeno://pairing?data=<base64url>` carries a small file in the link itself.
- `qeno://setup?relay=<origin>` sets the relay address Qeno Setup configured.

The pairing file and the setup state are mirrored into the Keychain (`SetupVault`,
`ThisDeviceOnly`). An update keeps the container anyway; a delete-and-reinstall, or a sideloading
tool that could not keep the container, gets both back on the first launch as long as the same team
signs the app, so the owner is not sent through setup again.

## Device test checklist

Install and launch
- [ ] Install `Qeno-unsigned.ipa`. Runner path only: also install the runner IPA with the same signing, and open Qeno Runner by hand: no passcode prompt, no automation banner; it opens Qeno (or shows Open Qeno).
- [ ] Launch Qeno: the Setup tab shows a badge with the steps left, and no Install Qeno Runner step.

Setup
- [ ] Each step opens in turn; Open Settings starts a Live Activity with the step number and what to tap.
- [ ] Loopback: the status changes within 3 s when the proxy app's module is turned on or off.
- [ ] Pairing: the code shows in the Live Activity and in Qeno; the step ticks.
- [ ] Let Qeno stay on: Allow location shows iOS's prompt; Live Activities show as on.

Turned on
- [ ] Turn on: the Live Activity says "On. Waiting for an agent"; once the session opens, the log says `in-process session ready` and the automation banner shows.
- [ ] An agent's first call finds the session open; its steps show on the Lock Screen and in the chat.
- [ ] No banner flicker during a run; a slow swipe or drag does not reopen the session.
- [ ] Runner path only: no banner until an agent's first call starts the runner; opening Qeno Runner while in use shows "Qeno is using this iPhone"; Stop on the Live Activity or in Qeno takes the banner away within seconds and the next call starts it again; after the idle time with no calls, the banner goes away by itself.
- [ ] Ten minutes in the background: the location pill shows and agents still reach the phone.
- [ ] Close Qeno from the app switcher: the banner goes away within seconds.
- [ ] A sensitive action shows Approve/Deny in the Live Activity; Approve asks for Face ID.

Connect
- [ ] Add a connector: the sheet shows the URL, a QR that scans to the same URL, and Copy works.
- [ ] Revoke by swiping: the connector disappears and the relay answers 404 for it.
