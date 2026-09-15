import Foundation

class XCTestCase {}
func XCTAssertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
    precondition(actual == expected, "\(message): Expected \(expected), got \(actual)", file: file, line: line)
}
func XCTAssertNil<T>(_ value: T?, file: StaticString = #file, line: UInt = #line) { precondition(value == nil, "Expected nil", file: file, line: line) }
func XCTAssertTrue(_ value: Bool, file: StaticString = #file, line: UInt = #line) { precondition(value, "Expected true", file: file, line: line) }
func XCTAssertFalse(_ value: Bool, file: StaticString = #file, line: UInt = #line) { precondition(!value, "Expected false", file: file, line: line) }

@main
struct SmokeRunner {
    @MainActor static func main() throws {
        let text = TextCleanerTests()
        text.testTrackingRemovalPreservesQueryBytesAndFragment()
        text.testUnicodeAndMultipleLinks()
        text.testOptionalCleanupPreservesEmojiJoiners()
        text.testDefaultsPreserveOrdinaryText()
        text.testEncodedTrackingName()
        print("PASS: 5 text cleanup tests")
        let clipboard = ClipboardTests()
        clipboard.testCopyAndPollingNeverStripFormatting()
        clipboard.testPlainTextCanBePastedWithoutRewriting()
        clipboard.testCopyDuringPasteExpiresRestoreWithoutCleaning()
        try clipboard.testRichTextCleanupAndRestore()
        clipboard.testSensitiveAndImageItemsAreUntouched()
        clipboard.testUndoNeverOverwritesNewCopy()
        clipboard.testMultipleItemsAreUntouched()
        print("PASS: 7 isolated clipboard tests")
    }
}
