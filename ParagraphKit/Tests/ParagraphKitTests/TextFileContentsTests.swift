import Foundation
import Testing
@testable import ParagraphKit

/// These are the tests that back the promise that Paragraph will not quietly
/// alter a writer's file. Every one of them is a round trip: read a file, change
/// nothing, write it back, and require the bytes to be identical.
@Suite("Text file reading and writing")
struct TextFileContentsTests {

    private func roundTrip(_ data: Data) throws -> Data {
        let contents = try TextFileContents.read(from: data)
        return try contents.data(for: contents.text)
    }

    // MARK: - Byte-for-byte preservation

    @Test("An unchanged UTF-8 file round-trips exactly")
    func utf8RoundTrip() throws {
        let data = Data("# Title\n\nSome prose.\n".utf8)
        #expect(try roundTrip(data) == data)
    }

    @Test("An unchanged CRLF file round-trips exactly")
    func crlfRoundTrip() throws {
        let data = Data("# Title\r\n\r\nSome prose.\r\n".utf8)
        #expect(try roundTrip(data) == data)
    }

    @Test("An unchanged classic Mac file round-trips exactly")
    func carriageReturnRoundTrip() throws {
        let data = Data("First\rSecond\rThird\r".utf8)
        #expect(try roundTrip(data) == data)
    }

    @Test("A byte-order mark survives a round trip")
    func byteOrderMarkRoundTrip() throws {
        let data = Data([0xEF, 0xBB, 0xBF]) + Data("# Title\n".utf8)
        let result = try roundTrip(data)
        #expect(result == data)
        #expect(result.starts(with: [0xEF, 0xBB, 0xBF]))
    }

    @Test("A file with no trailing newline does not gain one")
    func noTrailingNewline() throws {
        let data = Data("No newline at the end".utf8)
        #expect(try roundTrip(data) == data)
    }

    @Test("Unicode content round-trips exactly")
    func unicodeRoundTrip() throws {
        let data = Data("Se\u{00F1}ora — \u{201C}quoted\u{201D} — \u{4ECA}\u{65E5} \u{1F4DA}\n".utf8)
        #expect(try roundTrip(data) == data)
    }

    @Test("An empty file stays empty")
    func emptyFile() throws {
        #expect(try roundTrip(Data()) == Data())
    }

    // MARK: - Line endings

    @Test("Line-ending style is detected")
    func detection() {
        #expect(TextFileContents.detectLineEnding(in: "a\nb\nc") == .lineFeed)
        #expect(TextFileContents.detectLineEnding(in: "a\r\nb\r\nc") == .carriageReturnLineFeed)
        #expect(TextFileContents.detectLineEnding(in: "a\rb\rc") == .carriageReturn)
        #expect(TextFileContents.detectLineEnding(in: "a\r\nb\nc") == .mixed)
        #expect(TextFileContents.detectLineEnding(in: "no breaks") == .lineFeed)
    }

    @Test("A consistent file is normalised for editing but written back in style")
    func normalisedForEditing() throws {
        let contents = try TextFileContents.read(from: Data("a\r\nb\r\n".utf8))
        // The editor sees clean line feeds…
        #expect(contents.text == "a\nb\n")
        #expect(contents.lineEnding == .carriageReturnLineFeed)
        // …and the file keeps its own convention, including for new lines.
        #expect(try contents.data(for: "a\nb\nc\n") == Data("a\r\nb\r\nc\r\n".utf8))
    }

    @Test("A mixed file is left exactly as it was found")
    func mixedIsUntouched() throws {
        // Tidying this up would be a change the writer did not ask for.
        let original = "a\r\nb\nc\r\n"
        let contents = try TextFileContents.read(from: Data(original.utf8))
        #expect(contents.lineEnding == .mixed)
        #expect(contents.text == original)
        #expect(try contents.data(for: original) == Data(original.utf8))
    }

    // MARK: - Encodings

    @Test("A UTF-16 file is read and written as UTF-16")
    func utf16() throws {
        let text = "# Title\nSome prose.\n"
        let data = text.data(using: .utf16)!
        let contents = try TextFileContents.read(from: data)
        #expect(contents.text == text)
        #expect(contents.encoding == .utf16)
        #expect(try contents.data(for: contents.text) == data)
    }

    @Test("A non-UTF-8 file is decoded losslessly rather than rejected")
    func legacyEncoding() throws {
        // A lone 0xE9 is invalid UTF-8 but a valid legacy byte.
        let data = Data([0x63, 0x61, 0x66, 0xE9, 0x0A])
        let contents = try TextFileContents.read(from: data)
        #expect(contents.text.hasPrefix("caf"))
        #expect(contents.encoding != .utf8)
        // The point of the fallback: the bytes survive untouched.
        #expect(try contents.data(for: contents.text) == data)
        #expect(!contents.text.contains("\u{FFFD}"))
    }

    @Test("Editing changes only what the writer changed")
    func editedContent() throws {
        let original = Data("# Title\r\n\r\nOld line.\r\n".utf8)
        let contents = try TextFileContents.read(from: original)
        let edited = contents.text.replacingOccurrences(of: "Old line.", with: "New line.")
        #expect(try contents.data(for: edited) == Data("# Title\r\n\r\nNew line.\r\n".utf8))
    }
}
