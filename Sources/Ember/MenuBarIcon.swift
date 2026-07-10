import SwiftUI
import AppKit

/// Menu-bar glyph. `MenuBarExtra` sizes a bare SF Symbol `Image` label to its
/// own intrinsic content box and top-aligns it, which reliably renders small
/// and noticeably above center next to other status items — no combination
/// of `.font`/`.frame` on the SwiftUI side fixed it. Using a bespoke
/// template `NSImage` (see `Resources/MenuBar/*Template.png`, rendered
/// straight from the `flame.fill` / `flame` SF Symbols by
/// `scripts/render-symbol.swift` via `make-icons.sh`) sidesteps that layout
/// path entirely — AppKit centers a template `NSStatusItem` image the same
/// way it centers every other app's menu-bar icon, and the glyph itself is
/// pixel-identical to the SF Symbol.
struct MenuBarIcon: View {
    let runState: EmberRunState

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(nsImage: baseImage)
            if showsWarningBadge {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 9))
            }
        }
    }

    private var baseImage: NSImage {
        let name = runState == .keepingAwake ? "MenuBarActiveTemplate" : "MenuBarInactiveTemplate"
        let image = NSImage(named: name) ?? NSImage()
        image.isTemplate = true
        return image
    }

    private var showsWarningBadge: Bool {
        switch runState {
        case .error: return true
        case .idle, .keepingAwake: return false
        }
    }
}
