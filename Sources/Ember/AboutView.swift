import SwiftUI
import AppKit

struct AboutView: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1"
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Ember").font(.title).bold()
            Text("Version \(version)").foregroundStyle(.secondary)
            Text("Keep the fire going.").italic().foregroundStyle(.secondary)

            Link("View on GitHub", destination: URL(string: "https://github.com/AnonUser1035/ember")!)
                .padding(.top, 4)

            Text("MIT License")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(width: 280)
        .onAppear { NSApp.activate(ignoringOtherApps: true) }
    }
}
