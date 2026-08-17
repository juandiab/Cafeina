import AppKit
import SwiftUI

@MainActor
final class AboutWindowController: NSWindowController {
    static let shared = AboutWindowController()

    private init() {
        let hostingController = NSHostingController(rootView: AboutView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About Cafeina"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct AboutView: View {
    private var versionText: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)

            Text("Cafeina")
                .font(.title2.weight(.semibold))

            Text(versionText)
                .foregroundStyle(.secondary)

            Text("Keep your Mac awake from the menu bar.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Text("Not affiliated with Caffeine or any similarly named apps.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            HStack(spacing: 16) {
                Button("Privacy Policy") {
                    NSWorkspace.shared.open(AppLinks.privacyPolicy)
                }
                .buttonStyle(.link)

                Button("Support") {
                    NSWorkspace.shared.open(AppLinks.supportEmail)
                }
                .buttonStyle(.link)

                Button("Website") {
                    NSWorkspace.shared.open(AppLinks.supportWebsite)
                }
                .buttonStyle(.link)
            }

            Text("© \(Calendar.current.component(.year, from: Date())) \(AppLinks.copyrightOwner)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(AppLinks.supportEmailAddress)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(width: 360, height: 320)
    }
}
