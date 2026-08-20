import Foundation

/// How a file terminates its lines. Paragraph writes back whatever it read.
public enum LineEnding: String, Codable, Sendable {
    case lineFeed
    case carriageReturnLineFeed
    case carriageReturn
    /// The file mixes conventions. Paragraph will not tidy it up.
    case mixed

    public var characters: String {
        switch self {
        case .lineFeed, .mixed: return "\n"
        case .carriageReturnLineFeed: return "\r\n"
        case .carriageReturn: return "\r"
        }
    }
}

/// The result of reading a text file, along with everything needed to write it
/// back in exactly the form it arrived in.
///
/// Paragraph never normalises a file it did not change. Opening a document must
/// not alter a single byte, and saving must not quietly convert CRLF to LF or
/// strip a byte-order mark that some other tool is relying on.
public struct TextFileContents: Sendable {
    /// The text as the editor sees it, with line endings normalised to `\n`
    /// when — and only when — the file used one convention throughout.
    public var text: String
    public var encoding: String.Encoding
    public var lineEnding: LineEnding
    public var hasByteOrderMark: Bool

    public static let empty = TextFileContents(
        text: "",
        encoding: .utf8,
        lineEnding: .lineFeed,
        hasByteOrderMark: false
    )

    // MARK: - Reading

    public init(text: String, encoding: String.Encoding, lineEnding: LineEnding, hasByteOrderMark: Bool) {
        self.text = text
        self.encoding = encoding
        self.lineEnding = lineEnding
        self.hasByteOrderMark = hasByteOrderMark
    }

    public static func read(from data: Data) throws -> TextFileContents {
        let (decoded, encoding, hasBOM) = try decode(data)
        let lineEnding = detectLineEnding(in: decoded)

        // Only a file with one consistent convention is normalised for editing.
        // A mixed file is handed to the editor untouched, because any
        // normalisation would be a change the writer did not ask for.
        let text: String
        switch lineEnding {
        case .carriageReturnLineFeed:
            text = decoded.replacingOccurrences(of: "\r\n", with: "\n")
        case .carriageReturn:
            text = decoded.replacingOccurrences(of: "\r", with: "\n")
        case .lineFeed, .mixed:
            text = decoded
        }

        return TextFileContents(
            text: text,
            encoding: encoding,
            lineEnding: lineEnding,
            hasByteOrderMark: hasBOM
        )
    }

    private static func decode(_ data: Data) throws -> (String, String.Encoding, Bool) {
        if data.isEmpty { return ("", .utf8, false) }

        // Byte-order marks are authoritative when present.
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            let body = data.dropFirst(3)
            if let text = String(data: body, encoding: .utf8) { return (text, .utf8, true) }
        }
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) {
            if let text = String(data: data, encoding: .utf16) { return (text, .utf16, true) }
        }

        // The overwhelmingly common case.
        if let text = String(data: data, encoding: .utf8) { return (text, .utf8, false) }

        // Fall back to the system's own guess — but only if it is lossless.
        // A lossy decode would put replacement characters into the writer's
        // text and then write them back over their file.
        var converted: NSString?
        var lossy: ObjCBool = false
        let raw = NSString.stringEncoding(
            for: data,
            encodingOptions: [.suggestedEncodingsKey: [String.Encoding.utf8.rawValue,
                                                       String.Encoding.windowsCP1252.rawValue,
                                                       String.Encoding.macOSRoman.rawValue,
                                                       String.Encoding.isoLatin1.rawValue]],
            convertedString: &converted,
            usedLossyConversion: &lossy
        )
        if raw != 0, !lossy.boolValue, let converted {
            return (converted as String, String.Encoding(rawValue: raw), false)
        }

        // Latin-1 maps all 256 byte values, so this always succeeds and always
        // writes back the bytes it read. The characters shown may be wrong for a
        // file in some other legacy encoding, but nothing is ever corrupted.
        if let text = String(data: data, encoding: .isoLatin1) {
            return (text, .isoLatin1, false)
        }

        throw CocoaError(.fileReadUnknownStringEncoding)
    }

    static func detectLineEnding(in text: String) -> LineEnding {
        var carriageReturnLineFeed = 0
        var bareLineFeed = 0
        var bareCarriageReturn = 0

        // Swift treats CRLF as a single grapheme cluster, so it must be matched
        // as one character. Scanning for "\r" and "\n" separately finds neither.
        for character in text {
            switch character {
            case "\r\n": carriageReturnLineFeed += 1
            case "\r": bareCarriageReturn += 1
            case "\n": bareLineFeed += 1
            default: break
            }
        }

        let styles = [carriageReturnLineFeed, bareLineFeed, bareCarriageReturn].filter { $0 > 0 }
        if styles.count > 1 { return .mixed }
        if carriageReturnLineFeed > 0 { return .carriageReturnLineFeed }
        if bareCarriageReturn > 0 { return .carriageReturn }
        return .lineFeed
    }

    // MARK: - Writing

    /// Encodes `text` back into the file's original shape.
    public func data(for text: String) throws -> Data {
        let restored: String
        switch lineEnding {
        case .lineFeed, .mixed:
            restored = text
        case .carriageReturnLineFeed:
            restored = text.replacingOccurrences(of: "\n", with: "\r\n")
        case .carriageReturn:
            restored = text.replacingOccurrences(of: "\n", with: "\r")
        }

        guard var data = restored.data(using: encoding) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }

        if hasByteOrderMark, encoding == .utf8, !data.starts(with: [0xEF, 0xBB, 0xBF]) {
            data = Data([0xEF, 0xBB, 0xBF]) + data
        }
        return data
    }
}
