import AppKit
import SwiftUI

@main
struct EasyPasteApp: App {
    @StateObject private var controller = ClipboardController()
    @StateObject private var windows = SettingsWindow()

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable().frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("EasyPaste").font(.title3.bold())
                        Text("Plain text, on command.").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Circle().fill(controller.shortcutError == nil ? Color.green : Color.orange).frame(width: 8, height: 8)
                }
                Divider()
                Text("⌥⌘V").font(.system(size: 34, weight: .medium, design: .rounded))
                Text("Paste without formatting").font(.headline)
                Text("⌘C copies normally. ⌘V pastes normally.")
                    .font(.caption).foregroundStyle(.secondary)
                Text(controller.shortcutError ?? controller.status)
                    .font(.caption).foregroundStyle(controller.shortcutError == nil ? Color.secondary : Color.orange)
                Divider()
                HStack {
                    Button("Settings…") { windows.show(controller) }.keyboardShortcut(",")
                    Spacer()
                    Button("Quit") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
                }
            }.padding(20).frame(width: 340)
        } label: {
            Image(systemName: controller.shortcutError == nil ? "doc.on.clipboard" : "pause.circle")
        }.menuBarExtraStyle(.window)
    }
}

@MainActor
final class SettingsWindow: ObservableObject {
    private var window: NSWindow?
    func show(_ controller: ClipboardController) {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 700), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "EasyPaste Settings"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(controller: controller))
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @ObservedObject var controller: ClipboardController
    @AppStorage("typeToPreserveStyle") private var typeToPreserveStyle = false
    @AppStorage("removeTracking") private var removeTracking = true
    @AppStorage("removeInvisible") private var removeInvisible = false
    @AppStorage("normalizeQuotes") private var normalizeQuotes = false
    @AppStorage("removeReferences") private var removeReferences = false
    @AppStorage("normalizeNewlines") private var normalizeNewlines = false

    var body: some View {
        TabView {
            Form {
                Section {
                    Text("Press ⌥⌘V in any app to paste plain text.").font(.headline)
                    Text("⌘C and ⌘V keep their normal behavior. The original clipboard is restored after the plain-text paste.").font(.caption).foregroundStyle(.secondary)
                    Button("Enable Accessibility…") { controller.requestAccessibility() }
                    Text("Allow EasyPaste in System Settings → Privacy & Security → Accessibility so it can send the paste keystroke.").font(.caption).foregroundStyle(.secondary)
                    if let error = controller.shortcutError { Text(error).foregroundStyle(.orange) }
                } header: { Text("Paste shortcut · ⌥⌘V") }
                Section("Preserve the current text style") {
                    Toggle("Type short text instead of pasting", isOn: $typeToPreserveStyle)
                    Text("Try this when replacing a whole heading in Word Online. Sends text as typing so the editor can keep its current style. For short, single-line text; longer text, tabs, and newlines use standard paste. Results depend on the editor.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Text cleanup") {
                    Toggle("Remove common URL tracking parameters", isOn: $removeTracking)
                    Toggle("Remove invisible spaces and soft hyphens", isOn: $removeInvisible)
                    Toggle("Replace smart quotes with straight quotes", isOn: $normalizeQuotes)
                    Toggle("Remove footnote references, such as [1] and [a]", isOn: $removeReferences)
                    Toggle("Normalize line endings and extra blank lines", isOn: $normalizeNewlines)
                }
                Section("Startup") {
                    Toggle("Launch at login", isOn: Binding(get: { controller.loginEnabled }, set: { controller.setLogin($0) }))
                    if let error = controller.loginError { Text(error).font(.caption).foregroundStyle(.orange) }
                }
                Section {
                    Label("Clipboard content stays on this Mac", systemImage: "lock.shield")
                    Text("No network requests or clipboard history. The original clipboard is held briefly in memory during a plain-text paste. Files, images, and clipboard items marked as sensitive are skipped.").font(.caption).foregroundStyle(.secondary)
                }
            }.formStyle(.grouped).tabItem { Label("General", systemImage: "slider.horizontal.3") }
            VStack(spacing: 18) {
                Image(nsImage: NSApplication.shared.applicationIconImage).resizable().frame(width: 96, height: 96)
                Text("EasyPaste").font(.largeTitle.bold())
                Text("Plain text, on command.").font(.title3).foregroundStyle(.secondary)
                Text("Version 1.2.0").font(.caption)
                Text("An independent macOS utility inspired by Pure Paste.\nBuilt with Swift and native macOS controls.").multilineTextAlignment(.center).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, maxHeight: .infinity).tabItem { Label("About", systemImage: "info.circle") }
        }.padding(12).frame(width: 560, height: 700)
    }
}
