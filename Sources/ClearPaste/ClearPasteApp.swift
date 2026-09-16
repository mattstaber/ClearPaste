import AppKit
import SwiftUI

@main
struct ClearPasteApp: App {
    @StateObject private var controller = ClipboardController()
    @StateObject private var windows = SettingsWindow()

    var body: some Scene {
        MenuBarExtra {
            MenuPanel(controller: controller) { windows.show(controller) }
        } label: {
            Image(systemName: controller.shortcutError == nil ? "doc.on.clipboard" : "exclamationmark.circle")
        }.menuBarExtraStyle(.window)
    }
}

struct MenuPanel: View {
    @ObservedObject var controller: ClipboardController
    var openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 12) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable().frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text("ClearPaste").font(.title2.weight(.semibold))
                    Text("Plain text, on command.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            VStack(spacing: 14) {
                ShortcutKeys()
                Text("Paste without formatting").font(.headline)
                Text("Copy with ⌘C. Paste normally with ⌘V.")
                    .font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity).padding(.vertical, 8)
            Label(controller.shortcutError ?? (controller.accessibilityGranted ? controller.status : "Accessibility permission is required"),
                  systemImage: controller.shortcutError == nil ? "checkmark.circle" : "exclamationmark.triangle")
                .font(.caption).foregroundStyle(controller.shortcutError == nil ? Color.secondary : Color.orange)
                .fixedSize(horizontal: false, vertical: true)
            if !controller.accessibilityGranted {
                Button("Enable Accessibility…", systemImage: "hand.raised") { controller.requestAccessibility() }
                    .buttonStyle(.glassProminent)
                Text("After an update, you may need to remove ClearPaste from the Accessibility list and add this app again.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    Button("Settings…", systemImage: "slider.horizontal.3", action: openSettings)
                        .buttonStyle(.glassProminent).keyboardShortcut(",")
                    Spacer()
                    Button("Quit") { NSApplication.shared.terminate(nil) }
                        .buttonStyle(.glass).keyboardShortcut("q")
                }.controlSize(.large)
            }
        }.padding(24).frame(width: 360)
    }
}

struct ShortcutKeys: View {
    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                ForEach(["⌥", "⌘", "V"], id: \.self) { key in
                    Text(key).font(.system(size: 28, weight: .medium, design: .rounded))
                        .frame(width: 62, height: 58)
                        .glassEffect(.regular.tint(.cyan.opacity(0.12)), in: .rect(cornerRadius: 16))
                }
            }
        }.accessibilityElement(children: .ignore)
            .accessibilityLabel("Option Command V")
    }
}

@MainActor
final class SettingsWindow: ObservableObject {
    private var window: NSWindow?
    func show(_ controller: ClipboardController) {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 640), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            window.title = "ClearPaste Settings"
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(controller: controller))
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private enum SettingsPane: String, CaseIterable, Identifiable {
    case general = "General", cleanup = "Text Cleanup", about = "About"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .general: return "keyboard"
        case .cleanup: return "text.badge.checkmark"
        case .about: return "info.circle"
        }
    }
}

@MainActor
private final class SettingsNavigation: ObservableObject {
    @Published var selection: SettingsPane? = .general
}

struct SettingsView: View {
    @ObservedObject var controller: ClipboardController
    @StateObject private var navigation = SettingsNavigation()
    @AppStorage("typeToPreserveStyle") private var typeToPreserveStyle = false
    @AppStorage("removeTracking") private var removeTracking = true
    @AppStorage("removeInvisible") private var removeInvisible = false
    @AppStorage("normalizeQuotes") private var normalizeQuotes = false
    @AppStorage("removeReferences") private var removeReferences = false
    @AppStorage("normalizeNewlines") private var normalizeNewlines = false

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $navigation.selection) { pane in
                Label(pane.rawValue, systemImage: pane.symbol).tag(pane)
            }.navigationTitle("ClearPaste")
                .navigationSplitViewColumnWidth(min: 165, ideal: 180, max: 220)
        } detail: {
            Group {
                switch navigation.selection ?? .general {
                case .general: general
                case .cleanup: cleanup
                case .about: about
                }
            }.navigationTitle((navigation.selection ?? .general).rawValue)
        }.navigationSplitViewStyle(.balanced)
            .frame(minWidth: 680, minHeight: 520)
    }

    private var general: some View {
        Form {
            Section {
                HStack { Spacer(); ShortcutKeys(); Spacer() }.padding(.vertical, 12)
                Text("Paste without formatting").font(.headline)
                Text("⌘C and ⌘V work normally. Use ⌥⌘V when you want plain text.")
                    .foregroundStyle(.secondary)
                Button("Enable Accessibility…", systemImage: "hand.raised") { controller.requestAccessibility() }
                    .buttonStyle(.glassProminent)
                Text("Allow ClearPaste in System Settings → Privacy & Security → Accessibility to send the paste keystroke.")
                    .font(.caption).foregroundStyle(.secondary)
                if let error = controller.shortcutError { Text(error).foregroundStyle(.orange) }
            }
            Section("Preserve the current text style") {
                Toggle("Type short text instead of pasting", isOn: $typeToPreserveStyle)
                Text("Experimental: try this when replacing an entire heading in Word Online. If typing does not work in your editor, turn this off to use standard paste. Short, single-line text is sent as typing. Longer text, tabs, and newlines use standard paste. Results depend on the editor.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Startup") {
                Toggle("Launch at login", isOn: Binding(get: { controller.loginEnabled }, set: { controller.setLogin($0) }))
                if let error = controller.loginError { Text(error).font(.caption).foregroundStyle(.orange) }
            }
        }.formStyle(.grouped)
    }

    private var cleanup: some View {
        Form {
            Section("Clean up text when using ⌥⌘V") {
                Toggle("Remove common URL tracking parameters", isOn: $removeTracking)
                Toggle("Remove invisible spaces and soft hyphens", isOn: $removeInvisible)
                Toggle("Replace smart quotes with straight quotes", isOn: $normalizeQuotes)
                Toggle("Remove footnote references, such as [1] and [a]", isOn: $removeReferences)
                Toggle("Normalize line endings and extra blank lines", isOn: $normalizeNewlines)
            }
            Section {
                Label("Your clipboard stays on this Mac", systemImage: "lock.shield")
                Text("No network requests or clipboard history. Files, images, and clipboard items marked as sensitive are skipped. Your original formatting is restored after a standard plain-text paste.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }

    private var about: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApplication.shared.applicationIconImage).resizable().frame(width: 128, height: 128)
            Text("ClearPaste").font(.largeTitle.bold())
            Text("Plain text, on command.").font(.title3).foregroundStyle(.secondary)
            Text("Version 2.0.1").font(.caption).foregroundStyle(.secondary)
            Text("Built for Mac with Liquid Glass.\nAn independent utility inspired by Pure Paste.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(24)
    }
}
