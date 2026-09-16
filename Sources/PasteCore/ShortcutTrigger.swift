/// One request per complete shortcut press/release cycle; repeats never paste.
public struct ShortcutTrigger {
    private var held = false
    public init() {}
    public mutating func receive(isPressed: Bool) -> Bool {
        if isPressed { held = true; return false }
        guard held else { return false }
        held = false
        return true
    }
}
