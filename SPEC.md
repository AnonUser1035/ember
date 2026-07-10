# Ember — Build Specification

> A macOS menu-bar app that keeps your Mac fully awake **with the lid closed**, toggled with one click. Built for people running long tasks, builds, or coding agents on a laptop they want to shut and walk away from.
>
> This document is a handoff spec. Give it to Claude Code (or any engineer) as the source of truth for building the app and publishing it to GitHub.
>
> **Superseded:** the Phase 1 privileged-helper design below (`EmberHelper`, XPC, `SMAppService`) was built, then removed. Testing showed `SMAppService` daemon approval doesn't reliably complete without a real Apple Developer ID, and the added complexity wasn't worth it for what this app needs. Ember now only uses the Phase 0 admin-password-prompt approach described in §11. The rest of this document is kept for historical context.

---

## 1. Product summary

**What it does:** Adds a flame icon to the macOS menu bar. Click it, pick "Keep Awake," and the Mac will not sleep even when the lid is closed — no external display required, on battery or AC. Click again to release it and the Mac returns to normal power behavior.

**Why it's non-trivial:** Ordinary "stay awake" tools (like the built-in `caffeinate`) only block *idle* sleep. Closing the lid triggers *clamshell* sleep, which those tools do **not** prevent (except on AC power with an external display attached). The only reliable way to keep a laptop awake with the lid physically shut is the kernel-level flag `SleepDisabled`, set via:

```
sudo pmset -a disablesleep 1     # keep awake, even lid-closed
sudo pmset -a disablesleep 0     # restore normal sleep
```

This requires **root**. That single fact is the reason the app needs a privileged helper, and it drives most of the architecture below.

**Target OS:** macOS 13 Ventura and later (uses `MenuBarExtra` and `SMAppService`). Apple Silicon and Intel.

---

## 2. Branding

**Name:** **Ember** — a small fire kept glowing through the night; a campfire allusion that maps perfectly to "keep it burning while you're away." App label in the menu and About box: "Ember." Bundle identifier suggestion: `com.neurosafetysystems.ember` (adjust to your org).

Backup names if `Ember` is taken on the App Store / conflicts: *Stoke*, *Bonfire*, *Hearth*, *Nightwatch*, *Vigil*.

**Tagline:** "Keep the fire going." / "Shut the lid. Keep working."

**Color palette (campfire):**

| Role | Name | Hex |
|---|---|---|
| Primary flame | Ember Orange | `#FF6B35` |
| Secondary flame | Amber | `#FFB627` |
| Highlight core | Warm cream | `#FFF3C4` |
| Accent / coals | Coal Red | `#E63946` |
| Logs | Bark Brown | `#8B5A2B` |
| Background | Charcoal | `#1A1A1D` |

**Logo assets (provided alongside this spec):**

- `ember-appicon.svg` — full-color campfire (flame over crossed logs on charcoal, rounded square). Source for the `.icns` app icon. Render to the standard icon sizes (16, 32, 128, 256, 512 @1x and @2x) and compile into `AppIcon.appiconset` / `Ember.icns`.
- `ember-menubar-active.svg` — solid black flame, **template image**, shown when Ember is actively holding the Mac awake.
- `ember-menubar-inactive.svg` — outline black flame, **template image**, shown when idle.

Menu-bar icons must be exported as **template images** (name them `*Template` or set `isTemplate = true`) so macOS auto-tints them for light/dark menu bars. Target roughly 18pt; provide @1x and @2x PNGs (18×18 and 36×36).

**Menu-bar icon — two options (both use the same filled/outline flame concept):**

1. **SF Symbols (recommended for the prototype, and a fine permanent choice).** Use Apple's built-in `flame.fill` when active and `flame` when idle. These are already template images — macOS auto-tints them black on light menu bars and white on dark ones, so there's nothing to export and no light/dark assets to maintain. Zero-effort and always crisp at any menu-bar height:

   ```swift
   MenuBarExtra {
       MenuView()
   } label: {
       Image(systemName: isAwake ? "flame.fill" : "flame")
   }
   ```

   Preview the exact glyphs in Apple's free **SF Symbols** app. This is the fastest path to a working menu-bar icon and needs no artwork pipeline at all.

2. **Custom template PNGs from the provided SVGs.** For a more branded look, compile `ember-menubar-active.svg` (filled) and `ember-menubar-inactive.svg` (outline) into template PNGs (18×18 @1x, 36×36 @2x) and set `isTemplate = true`. The shapes deliberately mirror `flame.fill` / `flame`, so you can start on SF Symbols and swap to the custom art later with no logic change.

Either way, the full-color campfire (`ember-appicon.svg`) remains the app/Dock/About icon; only the menu-bar glyph is monochrome.

**State-to-icon mapping:**

- Idle → outline flame (`flame` / inactive template).
- Keeping awake → filled flame (`flame.fill` / active template). (Optional: subtle tint or a small badge; keep it template-friendly.)
- Helper not installed / error → filled flame with a small "!" overlay, or fall back to an SF Symbol like `flame.fill` alongside `exclamationmark.triangle`.

---

## 3. Architecture

Two code targets plus a shared protocol:

```
Ember.app                         (main GUI app, runs as the user)
 └─ Contents/
     ├─ MacOS/Ember               MenuBarExtra UI + XPC client
     ├─ Library/LaunchDaemons/
     │    com.neurosafetysystems.ember.helper.plist
     └─ Contents/MacOS/... 
com.neurosafetysystems.ember.helper   (privileged LaunchDaemon, runs as root)
     └─ runs pmset on request, over XPC
EmberShared                        (protocol + constants shared by both)
```

**Component 1 — Main app (user space):**
- SwiftUI `MenuBarExtra` app, `LSUIElement = true` (no Dock icon, no main window).
- Not sandboxed (App Sandbox cannot install privileged daemons; ship outside the Mac App Store).
- Owns UI state, the menu, preferences, timers, and the XPC client connection to the helper.

**Component 2 — Privileged helper (root):**
- A minimal command-line tool registered as a `SMAppService.daemon`.
- Exposes an XPC service (Mach service) with exactly two operations: `setAwake(Bool)` and `status()`.
- The ONLY privileged action it performs is running `pmset -a disablesleep 0/1` (via `/usr/bin/pmset`) and reading `pmset -g`. Keep its attack surface tiny — no arbitrary command execution, no shell.

**Component 3 — Shared framework/target (`EmberShared`):**
- Defines the `@objc` XPC protocol, the Mach service name, and version constants used by both sides to validate compatibility.

**Why a helper and not just an admin prompt?** An admin password dialog on every toggle (via `osascript … with administrator privileges`) is acceptable for a first prototype, but it's clunky for a "one click" tool. The `SMAppService` daemon is installed/approved once, then toggling is instant and password-free. See phased plan (§11) — build the prompt version first to de-risk, then graduate to the helper.

---

## 4. XPC protocol (shared)

```swift
// EmberShared/EmberHelperProtocol.swift
import Foundation

public let kEmberHelperMachName = "com.neurosafetysystems.ember.helper"
public let kEmberHelperVersion  = 1

@objc public protocol EmberHelperProtocol {
    /// Set the kernel SleepDisabled flag. reply(success, errorMessage?)
    func setKeepAwake(_ enabled: Bool, withReply reply: @escaping (Bool, String?) -> Void)

    /// Read current state: reply(isDisabled, helperVersion)
    func status(withReply reply: @escaping (Bool, Int) -> Void)
}
```

Helper implementation of `setKeepAwake` shells out to:
`/usr/bin/pmset -a disablesleep 1` (or `0`) using `Process`, checks the exit status, and replies. `status` runs `/usr/bin/pmset -g` and greps `SleepDisabled`.

**Security requirements on the connection:**
- Set `newConnection.setCodeSigningRequirement(...)` so the helper only accepts connections from a client signed with your Team ID (prevents other processes from driving the daemon). Verify the peer's code-signing identity.
- Validate `kEmberHelperVersion` on connect; if mismatched, the app should offer to reinstall the helper.

---

## 5. State machine & toggle logic

States: `idle`, `keepingAwake`, `helperMissing`, `error`.

Rules:
- **Toggle on:** call `setKeepAwake(true)`. On success → `keepingAwake`, icon = filled flame. On failure → `error`, surface message.
- **Toggle off:** call `setKeepAwake(false)` → `idle`, icon = outline.
- **On app launch:** call `status()`. Reconcile UI to actual kernel state (the flag persists across app restarts and reboots — the app must not assume it owns the truth).
- **On app quit:** default behavior = **turn keep-awake OFF** (call `setKeepAwake(false)`) so the machine isn't silently left un-sleepable forever. Make this configurable ("Keep awake even after I quit Ember") but default to safe.
- **Optional auto-timer:** "Keep awake for [30 min / 1 hr / 2 hr / 5 hr / until I stop]." When the timer expires, auto-toggle off. Great safety net for the #1 hazard (forgetting it's on).

---

## 6. Safety features (important — this flag is a footgun)

The single biggest real-world risk is leaving `disablesleep` on and returning to a hot, battery-drained laptop. The app must actively protect against this:

1. **Restore on quit** (default on, see §5).
2. **Optional auto-off timer** (§5).
3. **Low-battery guard:** if on battery and level drops below a threshold (default 20%, configurable), automatically turn keep-awake off and post a notification. Poll battery via `IOPowerSources` / `NSProcessInfo` power state.
4. **Persistent status visibility:** the filled flame in the menu bar is the always-on reminder. Optionally show elapsed time in the menu ("Awake for 1h 14m").
5. **Thermal note in UI + README:** closing the lid restricts airflow on many MacBooks; sustained heavy load lid-closed can get hot. Surface a one-time caution the first time the user enables it.
6. **Notification on enable/disable** so state changes are never silent.
7. **Crash recovery:** because the flag persists even if the app crashes, on next launch the app reconciles via `status()` and, if it finds the flag set but has no timer/session record, prompts: "Ember left your Mac set to stay awake. Turn sleep back on?"

---

## 7. Menu UI

`MenuBarExtra` content (SwiftUI), top to bottom:

- **Toggle row:** "Keep Awake" with a checkmark / switch reflecting state. Primary action.
- When active: subtitle line "Awake — lid can stay closed · 1h 02m".
- **Duration submenu:** Indefinitely (default), 30 min, 1 hour, 2 hours, 5 hours.
- Divider.
- **Launch at login** toggle (via `SMAppService.mainApp.register()`).
- **Settings…** (opens a small preferences window: battery threshold, restore-on-quit, notifications, default duration).
- **About Ember** (version, link to GitHub repo, license).
- **Quit Ember.**

If helper is missing/not approved, replace the toggle with a **"Set up Ember…"** call-to-action that launches onboarding (§8).

---

## 8. First-run onboarding (SMAppService approval)

`SMAppService` cannot silently install a root daemon. The flow:

1. On first enable, call `SMAppService.daemon(plistName:).register()`.
2. macOS will require the user to approve the background item in **System Settings → General → Login Items & Extensions** (and enter their password to authorize the daemon). The API cannot present that prompt inline.
3. So the app must show a friendly onboarding sheet: explain why root is needed (to set the sleep flag), then deep-link the user to Settings using `SMAppService.openSystemSettingsLoginItems()`. Poll `service.status` and advance automatically once it becomes `.enabled`.
4. Handle all `SMAppService.Status` cases: `.notRegistered`, `.enabled`, `.requiresApproval`, `.notFound`. Show the right guidance for each.

Document this clearly — it's the single most common place these apps confuse users.

---

## 9. Project structure

```
ember/
├─ Ember.xcodeproj
├─ Ember/                         # main app target
│   ├─ EmberApp.swift             # @main, MenuBarExtra
│   ├─ AppState.swift             # ObservableObject, state machine
│   ├─ HelperClient.swift         # XPC client + install/approve logic
│   ├─ MenuView.swift
│   ├─ SettingsView.swift
│   ├─ Onboarding.swift
│   ├─ Assets.xcassets            # AppIcon + menu-bar template images
│   └─ Info.plist                 # LSUIElement=YES, LSMinimumSystemVersion=13.0
├─ EmberHelper/                   # privileged daemon target
│   ├─ main.swift                 # NSXPCListener setup
│   ├─ HelperService.swift        # implements EmberHelperProtocol, runs pmset
│   ├─ Info.plist
│   └─ com.neurosafetysystems.ember.helper.plist   # LaunchDaemon plist
├─ EmberShared/                   # shared protocol + constants
│   └─ EmberHelperProtocol.swift
├─ scripts/
│   ├─ make-icons.sh              # svg → iconset → icns
│   └─ build-dmg.sh
├─ .github/workflows/release.yml  # CI: build, (notarize), attach DMG to release
├─ README.md
├─ LICENSE                        # MIT recommended
└─ SPEC.md                        # this file
```

**Key Info.plist / entitlements notes:**
- Main app: `LSUIElement = YES`, `LSMinimumSystemVersion = 13.0`.
- Helper `.plist`: `Label`, `BundleProgram` pointing at the helper binary, `MachServices` = `{ com.neurosafetysystems.ember.helper = YES }`.
- The helper must live in `Contents/Library/LaunchDaemons/` inside the app bundle; the executable in `Contents/MacOS/`.
- Both app and helper must be signed with the **same Team ID**; XPC code-signing requirements check `anchor apple generic and certificate leaf[subject.OU] = "<TEAMID>"`.

---

## 10. Build, signing & distribution

**To develop and run locally you need:**
- A Mac running macOS 13+.
- **Xcode** (free from the Mac App Store) — the IDE + Swift compiler + Interface tooling.
- An **Apple ID**. A free Apple ID can sign apps to run on *your own* Mac. To let *other people* run it without Gatekeeper warnings you need a paid **Apple Developer Program** membership ($99/yr) to get a **Developer ID** certificate and to **notarize** the app.

**Signing reality for a privileged-helper app:**
- `SMAppService` daemons must be signed. For local testing a free/development signing identity works on your own machine.
- For public distribution, sign both targets with **Developer ID Application**, then **notarize** the `.app` (via `notarytool`) and staple it. Without notarization, users get "Ember can't be opened because Apple cannot check it for malicious software" and must right-click→Open or clear quarantine — document this fallback in the README for people who build from source unsigned.

**Distribution channel:** GitHub Releases with a signed, notarized `.dmg` (built by `scripts/build-dmg.sh`). Not the Mac App Store — sandbox rules forbid installing privileged daemons.

---

## 11. Phased delivery plan

**Phase 0 — Prototype (no helper, prove the concept):**
- MenuBarExtra with the two icon states using SF Symbols (`flame.fill` / `flame`) — no artwork pipeline needed yet.
- Toggle runs `pmset` via an admin-authenticated AppleScript (`NSAppleScript` `do shell script "pmset -a disablesleep 1" with administrator privileges`). This shows the native password dialog each time. No signing gymnastics. Confirms the core behavior end-to-end.

**Phase 1 — Privileged helper:**
- Add `EmberShared` protocol + `EmberHelper` daemon + `SMAppService` install/approve flow + XPC. Password-free toggling after one-time approval.

**Phase 2 — Safety & polish:**
- Auto-off timer, low-battery guard, restore-on-quit, crash reconciliation, notifications, elapsed-time display, Settings window, launch-at-login.

**Phase 3 — Branding & release:**
- Compile icons from the provided SVGs, About box, DMG builder, notarization, GitHub Release + CI, README with screenshots and the Gatekeeper/approval instructions.

---

## 12. Acceptance criteria / test checklist

- [ ] Enabling keep-awake sets `pmset -g | grep SleepDisabled` to `1`; disabling sets it to `0`.
- [ ] With keep-awake ON, closing the lid on **battery, no external display** does NOT sleep the Mac (verify with `pmset -g log` or an SSH session staying alive).
- [ ] Icon reflects state and updates on external changes (e.g., someone runs `pmset` in Terminal).
- [ ] Quitting Ember restores normal sleep (default setting).
- [ ] Auto-off timer disables at the chosen time.
- [ ] Low-battery guard trips at threshold and notifies.
- [ ] Fresh install: onboarding correctly walks through the Login Items approval; app recovers if user cancels.
- [ ] Helper rejects XPC connections from processes not signed with the app's Team ID.
- [ ] App launches with no Dock icon and no window (LSUIElement).
- [ ] After a forced-crash while active, next launch detects the lingering flag and offers to reset it.

---

## 13. README must include (for the public repo)

- One-line pitch + the campfire icon.
- What it does and the honest "why plain caffeinate isn't enough" explanation.
- Requirements (macOS 13+).
- Install: download DMG from Releases, drag to Applications, first-run approval steps (with screenshots of the Login Items panel).
- The **safety caveats**: it disables ALL sleep until turned off; heat when lid-closed under load; battery drain. Recommend using the auto-off timer.
- Build-from-source instructions (unsigned) + the Gatekeeper right-click-Open workaround.
- License (MIT).

---

## 14. Prior art to reference (not copy)

- `Lidless` — a MenuBarExtra + privileged-helper app with exactly this goal; good structural reference for the SMAppService/XPC wiring.
- `KeepingYouAwake` — popular open-source caffeinate wrapper; good reference for menu-bar UX and timer options (but it does NOT do lid-closed, which is Ember's differentiator).
- `HelperToolApp` / `SwiftAuthorizationSample` — reference implementations of SMAppService-based privileged helpers with secure XPC.
