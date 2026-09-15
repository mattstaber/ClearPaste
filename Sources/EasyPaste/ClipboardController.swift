import AppKit
import Combine
import ServiceManagement
import PasteCore

@MainActor
final class ClipboardController: ObservableObject {
    @Published var cleanedCount = 0
    @Published var status = "Press ⌥⌘V to paste plain text"
    @Published var loginEnabled = SMAppService.mainApp.status == .enabled
    @Published var loginError: String?
    private let pasteboard: NSPasteboard
    private var lastChange: Int
    private var timer: Timer?
    private var hotKey: PasteHotKey?
    @Published var shortcutError: String?
    @Published var isPasting = false
    private var undoItems: [[NSPasteboard.PasteboardType: Data]]?
    private var undoChange: Int?
    @Published var canUndo = false

    init(pasteboard: NSPasteboard = .general, startMonitoring: Bool = true) {
        self.pasteboard = pasteboard
        lastChange = pasteboard.changeCount
        if startMonitoring {
            hotKey = PasteHotKey { [weak self] in self?.pastePlainText() }
            shortcutError = hotKey?.error

            timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.poll() }
            }
        }
    }

    var options: CleaningOptions {
        let defaults = UserDefaults.standard
        var options = CleaningOptions()
        options.removeTracking = defaults.object(forKey: "removeTracking") as? Bool ?? true
        options.removeInvisible = defaults.bool(forKey: "removeInvisible")
        options.normalizeQuotes = defaults.bool(forKey: "normalizeQuotes")
        options.removeReferences = defaults.bool(forKey: "removeReferences")
        options.normalizeNewlines = defaults.bool(forKey: "normalizeNewlines")
        return options
    }

    func poll() {
        guard pasteboard.changeCount != lastChange else { return }
        lastChange = pasteboard.changeCount
        undoItems = nil
        canUndo = false
        // Copying is never transformed. Polling only expires the restore snapshot.
    }

    func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    func pastePlainText() {
        guard !isPasting else { return }
        guard AXIsProcessTrusted() else {
            status = "Enable Accessibility in Settings to use ⌥⌘V"
            return
        }
        guard let target = NSWorkspace.shared.frontmostApplication,
              target.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        isPasting = true
        Task { @MainActor in
            defer { isPasting = false }
            // Wait for physical modifiers to lift so Option cannot leak into the paste.
            for _ in 0..<200 {
                let flags = CGEventSource.flagsState(.combinedSessionState)
                if flags.intersection([.maskCommand, .maskAlternate, .maskControl, .maskShift]).isEmpty { break }
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
            let flags = CGEventSource.flagsState(.combinedSessionState)
            guard flags.intersection([.maskCommand, .maskAlternate, .maskControl, .maskShift]).isEmpty,
                  NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier else {
                status = "Paste cancelled because focus or held keys changed"
                return
            }
            guard let source = CGEventSource(stateID: .privateState),
                  let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
                status = "Could not create paste event"
                return
            }
            guard cleanClipboard() else { return }
            down.flags = .maskCommand
            up.flags = .maskCommand
            down.postToPid(target.processIdentifier)
            up.postToPid(target.processIdentifier)
            // macOS has no paste-completion callback. Allow the receiving app to read
            // the temporary text, then restore only if no newer copy has arrived.
            try? await Task.sleep(nanoseconds: 800_000_000)
            if canUndo { undo() }
            status = "Plain-text paste sent · original clipboard kept"
        }
    }

    @discardableResult
    func cleanClipboard() -> Bool {
        let change = pasteboard.changeCount
        guard let items = pasteboard.pasteboardItems, items.count == 1, let item = items.first else {
            status = "Skipped non-text or multiple items"; return false
        }
        let types = item.types.map(\.rawValue)
        let protected = types.contains { type in
            let lower = type.lowercased()
            return lower.contains("concealed") || lower.contains("transient") || lower.contains("password") || lower.contains("1password") || lower.contains("promised") || lower.contains("file-url") || lower.contains("filenames") || lower.contains("image") || lower.contains("png") || lower.contains("tiff") || lower.contains("jpeg") || lower.contains("pdf")
        }
        guard !protected else { status = "Kept protected or non-text content"; return false }
        guard let text = item.string(forType: .string) else { status = "No plain-text representation to clean"; return false }
        let cleaned = TextCleaner.clean(text, options: options)
        let rich = item.types.contains(.rtf) || item.types.contains(.html) || item.types.contains(.rtfd)
        guard rich || text != cleaned else { status = "Already plain and clean"; return true }
        var snapshot: [NSPasteboard.PasteboardType: Data] = [:]
        for type in item.types { if let data = item.data(forType: type) { snapshot[type] = data } }
        guard pasteboard.changeCount == change else { status = "Clipboard changed; skipped stale copy"; return false }
        let output = NSPasteboardItem()
        output.setString(cleaned, forType: .string)
        // Preserve clipboard-manager metadata, but never stale rich-text representations.
        for (type, data) in snapshot where type.rawValue.hasPrefix("org.nspasteboard.") || type.rawValue == "org.pasteboard.source" {
            output.setData(data, forType: type)
        }
        pasteboard.clearContents()
        guard pasteboard.writeObjects([output]) else { status = "Could not write to clipboard"; lastChange = pasteboard.changeCount; return false }
        lastChange = pasteboard.changeCount
        undoItems = [snapshot]
        undoChange = lastChange
        canUndo = true
        cleanedCount += 1
        status = "Formatting cleared · ready to paste"
        return true
    }

    func undo() {
        guard let snapshots = undoItems, pasteboard.changeCount == undoChange else {
            undoItems = nil; canUndo = false; status = "Clipboard has changed; cannot restore"; return
        }
        let items = snapshots.map { snapshot -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in snapshot { item.setData(data, forType: type) }
            return item
        }
        pasteboard.clearContents()
        pasteboard.writeObjects(items)
        lastChange = pasteboard.changeCount
        undoItems = nil
        canUndo = false
        status = "Original formatting restored"
    }

    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginEnabled = SMAppService.mainApp.status == .enabled
            loginError = SMAppService.mainApp.status == .requiresApproval ? "Allow EasyPaste in System Settings → General → Login Items." : nil
        } catch { loginError = error.localizedDescription; loginEnabled = SMAppService.mainApp.status == .enabled }
    }
}
