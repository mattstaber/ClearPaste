#if !STANDALONE_TESTS
import XCTest
#endif
import AppKit
import PasteCore
#if !STANDALONE_TESTS
@testable import ClearPaste
#endif

final class TextCleanerTests: XCTestCase {
    func testShortcutWaitsForReleaseAndIgnoresRepeats() {
        var trigger = ShortcutTrigger()
        XCTAssertFalse(trigger.receive(isPressed: true))
        XCTAssertFalse(trigger.receive(isPressed: true))
        XCTAssertTrue(trigger.receive(isPressed: false))
        XCTAssertFalse(trigger.receive(isPressed: false))
        XCTAssertFalse(trigger.receive(isPressed: true))
        XCTAssertTrue(trigger.receive(isPressed: false))
    }
    func testUnpairedReleaseDoesNotPaste() {
        var trigger = ShortcutTrigger()
        XCTAssertFalse(trigger.receive(isPressed: false))
    }
    func testTypingPlanPreservesUnicodeAndBounds() {
        let text = "A heading 👩‍💻 café e\u{301} " + String(repeating: "a", count: 55)
        let chunks = TypingPlan.chunks(for: text)!
        XCTAssertEqual(chunks.map { String(decoding: $0, as: UTF16.self) }.joined(), text)
        XCTAssertTrue(chunks.allSatisfy { !$0.isEmpty && $0.count <= 20 })
    }
    func testTypingPlanFallsBackForControlsAndLongText() {
        for text in ["", "a\nb", "a\rb", "a\tb", "a\u{2028}b", "a\u{001B}b", String(repeating: "a", count: 2001)] {
            XCTAssertNil(TypingPlan.chunks(for: text))
        }
        XCTAssertTrue(TypingPlan.chunks(for: String(repeating: "a", count: 2000)) != nil)
        XCTAssertNil(TypingPlan.chunks(for: "a" + String(repeating: "\u{301}", count: 25)))
    }
    func testTrackingRemovalPreservesQueryBytesAndFragment() {
        XCTAssertEqual(TextCleaner.cleanURL("https://example.com/p?q=a%20b&utm_source=test&token=a+b#section"), "https://example.com/p?q=a%20b&token=a+b#section")
        XCTAssertEqual(TextCleaner.cleanURL("https://example.com/?fbclid=123#top"), "https://example.com/#top")
        XCTAssertEqual(TextCleaner.cleanURL("https://example.com/?ref=useful&x=1"), "https://example.com/?ref=useful&x=1")
    }
    func testUnicodeAndMultipleLinks() {
        let text = "👋 https://example.com/?utm_source=a&x=2 and https://example.org/?gclid=b"
        XCTAssertEqual(TextCleaner.clean(text, options: CleaningOptions()), "👋 https://example.com/?x=2 and https://example.org/")
    }
    func testOptionalCleanupPreservesEmojiJoiners() {
        var options = CleaningOptions()
        options.removeInvisible = true
        options.normalizeQuotes = true
        options.removeReferences = true
        options.normalizeNewlines = true
        XCTAssertEqual(TextCleaner.clean("“Hello”\u{200B}[12]\r\n\r\n\r\n👩‍💻", options: options), "\"Hello\"\n\n👩‍💻")
    }
    func testDefaultsPreserveOrdinaryText() {
        let text = "‘quote’ [1]\r\n\r\n\r\nlet values = [a]"
        XCTAssertEqual(TextCleaner.clean(text, options: CleaningOptions()), text)
    }
    func testEncodedTrackingName() {
        XCTAssertEqual(TextCleaner.cleanURL("https://example.com/?%75tm_source=x&a=&a=2"), "https://example.com/?a=&a=2")
    }
}

final class ClipboardTests: XCTestCase {
    @MainActor
    func testTypingPreparationKeepsClipboardIntact() {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let item = NSPasteboardItem()
        item.setString("Heading", forType: .string)
        item.setString("<h1>Heading</h1>", forType: .html)
        board.writeObjects([item])
        let controller = ClipboardController(pasteboard: board, startMonitoring: false)
        let before = board.changeCount
        XCTAssertEqual(controller.cleanedText(), "Heading")
        XCTAssertEqual(board.changeCount, before)
        XCTAssertEqual(board.string(forType: .html), "<h1>Heading</h1>")
    }
    @MainActor
    func testRepeatedCleanupRetainsOriginalSnapshot() {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let item = NSPasteboardItem()
        item.setString("Heading", forType: .string)
        item.setString("<h1>Heading</h1>", forType: .html)
        board.writeObjects([item])
        let controller = ClipboardController(pasteboard: board, startMonitoring: false)
        XCTAssertTrue(controller.cleanClipboard())
        XCTAssertTrue(controller.cleanClipboard())
        controller.undo()
        XCTAssertEqual(board.string(forType: .html), "<h1>Heading</h1>")
    }
    @MainActor
    func testCopyAndPollingNeverStripFormatting() {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let controller = ClipboardController(pasteboard: board, startMonitoring: false)
        let item = NSPasteboardItem()
        item.setString("copied text", forType: .string)
        item.setString("<b>copied text</b>", forType: .html)
        board.writeObjects([item])
        let change = board.changeCount
        controller.poll()
        XCTAssertEqual(board.changeCount, change)
        XCTAssertEqual(board.string(forType: .html), "<b>copied text</b>")
        XCTAssertFalse(controller.canUndo)
    }
    @MainActor
    func testPlainTextCanBePastedWithoutRewriting() {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("plain text", forType: .string)
        let controller = ClipboardController(pasteboard: board, startMonitoring: false)
        let change = board.changeCount
        XCTAssertTrue(controller.cleanClipboard())
        XCTAssertEqual(board.changeCount, change)
        XCTAssertFalse(controller.canUndo)
    }
    @MainActor
    func testCopyDuringPasteExpiresRestoreWithoutCleaning() {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let item = NSPasteboardItem()
        item.setString("first", forType: .string)
        item.setString("<b>first</b>", forType: .html)
        board.writeObjects([item])
        let controller = ClipboardController(pasteboard: board, startMonitoring: false)
        XCTAssertTrue(controller.cleanClipboard())
        board.clearContents()
        let newer = NSPasteboardItem()
        newer.setString("new", forType: .string)
        newer.setString("<i>new</i>", forType: .html)
        board.writeObjects([newer])
        controller.poll()
        XCTAssertFalse(controller.canUndo)
        XCTAssertEqual(board.string(forType: .html), "<i>new</i>")
    }
    @MainActor
    func testRichTextCleanupAndRestore() throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let original = NSPasteboardItem()
        original.setString("Hello", forType: .string)
        let rtf = Data("{\\rtf1 Hello}".utf8)
        original.setData(rtf, forType: .rtf)
        board.writeObjects([original])
        let controller = ClipboardController(pasteboard: board, startMonitoring: false)
        controller.cleanClipboard()
        XCTAssertEqual(board.string(forType: .string), "Hello")
        XCTAssertNil(board.data(forType: .rtf))
        XCTAssertTrue(controller.canUndo)
        controller.undo()
        XCTAssertEqual(board.data(forType: .rtf), rtf)
        XCTAssertFalse(controller.canUndo)
    }
    @MainActor
    func testSensitiveAndImageItemsAreUntouched() {
        for type in ["org.nspasteboard.ConcealedType", "public.png", "public.file-url", "com.agilebits.onepassword", "org.nspasteboard.TransientType"] {
            let board = NSPasteboard.withUniqueName()
            defer { board.releaseGlobally() }
            let item = NSPasteboardItem()
            item.setString("secret", forType: .string)
            item.setString("rich", forType: .html)
            item.setData(Data([1]), forType: NSPasteboard.PasteboardType(type))
            board.writeObjects([item])
            let controller = ClipboardController(pasteboard: board, startMonitoring: false)
            let before = board.changeCount
            XCTAssertNil(controller.cleanedText())
            controller.cleanClipboard()
            XCTAssertEqual(board.changeCount, before, type)
            XCTAssertFalse(controller.canUndo)
        }
    }
    @MainActor
    func testUndoNeverOverwritesNewCopy() {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let item = NSPasteboardItem()
        item.setString("first", forType: .string)
        item.setString("<b>first</b>", forType: .html)
        board.writeObjects([item])
        let controller = ClipboardController(pasteboard: board, startMonitoring: false)
        controller.cleanClipboard()
        board.clearContents()
        board.setString("new copy", forType: .string)
        controller.undo()
        XCTAssertEqual(board.string(forType: .string), "new copy")
    }
    @MainActor
    func testMultipleItemsAreUntouched() {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let items = ["one", "two"].map { text -> NSPasteboardItem in
            let item = NSPasteboardItem()
            item.setString(text, forType: .string)
            item.setString("<b>\(text)</b>", forType: .html)
            return item
        }
        board.writeObjects(items)
        let before = board.changeCount
        ClipboardController(pasteboard: board, startMonitoring: false).cleanClipboard()
        XCTAssertEqual(board.changeCount, before)
    }
}
