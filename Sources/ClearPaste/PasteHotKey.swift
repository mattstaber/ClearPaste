import AppKit
import Carbon

/// Registers only Option-Command-V; ordinary copy and paste events are untouched.
@MainActor
final class PasteHotKey {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var isHeld = false
    private let action: @MainActor () -> Void
    private(set) var error: String?

    init(action: @escaping @MainActor () -> Void) {
        self.action = action
        var events = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context, let event else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard result == noErr, identifier.signature == 0x45505354, identifier.id == 1 else { return OSStatus(eventNotHandledErr) }
            let object = Unmanaged<PasteHotKey>.fromOpaque(context).takeUnretainedValue()
            let pressed = GetEventKind(event) == UInt32(kEventHotKeyPressed)
            Task { @MainActor in
                if pressed {
                    guard !object.isHeld else { return }
                    object.isHeld = true
                    object.action()
                } else { object.isHeld = false }
            }
            return noErr
        }, 2, &events, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard installed == noErr else { error = "Could not install shortcut handler (\(installed))."; return }
        let registered = RegisterEventHotKey(UInt32(kVK_ANSI_V), UInt32(optionKey | cmdKey), EventHotKeyID(signature: 0x45505354, id: 1), GetApplicationEventTarget(), 0, &hotKey)
        if registered != noErr { error = "Could not register ⌥⌘V (\(registered)). Another app may be using it." }
    }

    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }
}
