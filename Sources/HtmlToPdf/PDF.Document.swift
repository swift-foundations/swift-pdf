//
//  PDF.Document.swift
//  swift-html-to-pdf
//
//  Document model for PDF rendering
//

import Foundation
import PointFreeHTML

extension PDF {
    /// A document to be rendered as a PDF
    ///
    /// Examples:
    /// ```swift
    /// // Using PointFree HTML DSL (type-safe)
    /// struct MyPage: HTMLDocumentProtocol {
    ///     var head: some HTML { title { "My PDF" } }
    ///     var body: some HTML { h1 { "Hello, World!" } }
    /// }
    /// let doc = PDF.Document(html: MyPage(), destination: fileURL)
    ///
    /// // Using String (simple)
    /// let doc = PDF.Document(htmlString: "<html><body>Hello</body></html>", destination: fileURL)
    ///
    /// // Using raw bytes (advanced)
    /// let doc = PDF.Document(htmlBytes: bytes, destination: fileURL)
    /// ```
    public struct Document: Sendable {
        let htmlBytes: ContiguousArray<UInt8>
        public let destination: URL

        // MARK: - Primary Initializers (HTML protocol)

        /// Create a document from any HTML-conforming type
        public init<H: HTML>(html: H, destination: URL) {
            self.htmlBytes = html.render()
            self.destination = destination
        }

        public init<H: HTML>(html: H, title: String, in directory: URL) {
            self.htmlBytes = html.render()
            self.destination = directory
                .appendingPathComponent(title.replacingSlashesWithDivisionSlash())
                .appendingPathExtension("pdf")
        }

        // MARK: - Convenience Initializers

        /// Create a document from raw HTML bytes (advanced usage)
        public init(htmlBytes: ContiguousArray<UInt8>, destination: URL) {
            self.htmlBytes = htmlBytes
            self.destination = destination
        }

        public init(htmlBytes: ContiguousArray<UInt8>, title: String, in directory: URL) {
            self.htmlBytes = htmlBytes
            self.destination = directory
                .appendingPathComponent(title.replacingSlashesWithDivisionSlash())
                .appendingPathExtension("pdf")
        }

        /// Create a document from an HTML string (convenience)
        public init(htmlString: String, destination: URL) {
            self.htmlBytes = ContiguousArray(htmlString.utf8)
            self.destination = destination
        }

        public init(htmlString: String, title: String, in directory: URL) {
            self.htmlBytes = ContiguousArray(htmlString.utf8)
            self.destination = directory
                .appendingPathComponent(title.replacingSlashesWithDivisionSlash())
                .appendingPathExtension("pdf")
        }

        // MARK: - Internal Access

        /// Access the HTML bytes for rendering
        var html: ContiguousArray<UInt8> { htmlBytes }
    }
}

// MARK: - String Utilities

extension String {
    func replacingSlashesWithDivisionSlash() -> String {
        let divisionSlash = "\u{2215}" // Unicode for Division Slash (∕)
        return self.replacingOccurrences(of: "/", with: divisionSlash)
    }
}

// MARK: - ContiguousArray Utilities

extension ContiguousArray where Element == UInt8 {
    /// Injects CSS bytes into HTML, either before </head> or at the beginning
    func injectingCSS(_ cssBytes: ContiguousArray<UInt8>) -> ContiguousArray<UInt8> {
        let headEndBytes = ContiguousArray("</head>".utf8)
        let headStartBytes = ContiguousArray("<head>".utf8)
        let bodyBytes = ContiguousArray("<body".utf8)

        // Try to inject before </head>
        if let range = self.firstRange(of: headEndBytes, options: .caseInsensitive) {
            var result = ContiguousArray<UInt8>()
            result.reserveCapacity(self.count + cssBytes.count)
            result.append(contentsOf: self[..<range.lowerBound])
            result.append(contentsOf: cssBytes)
            result.append(contentsOf: self[range.lowerBound...])
            return result
        }
        // Try to inject after <head>
        else if let headRange = self.firstRange(of: headStartBytes, options: .caseInsensitive) {
            // Find closing >
            if let closingBracket = self[headRange.upperBound...].firstIndex(of: UInt8(ascii: ">")) {
                let insertPoint = self.index(after: closingBracket)
                var result = ContiguousArray<UInt8>()
                result.reserveCapacity(self.count + cssBytes.count)
                result.append(contentsOf: self[..<insertPoint])
                result.append(contentsOf: cssBytes)
                result.append(contentsOf: self[insertPoint...])
                return result
            }
        }
        // Try to inject before <body>
        else if let bodyRange = self.firstRange(of: bodyBytes, options: .caseInsensitive) {
            var result = ContiguousArray<UInt8>()
            result.reserveCapacity(self.count + cssBytes.count)
            result.append(contentsOf: self[..<bodyRange.lowerBound])
            result.append(contentsOf: cssBytes)
            result.append(contentsOf: self[bodyRange.lowerBound...])
            return result
        }

        // Otherwise inject at the beginning
        var result = cssBytes
        result.append(contentsOf: self)
        return result
    }

    /// Convert to Data for WKWebView loading
    func toData() -> Data {
        Data(self)
    }
}

// MARK: - Byte Search Utilities

extension ContiguousArray where Element == UInt8 {
    enum SearchOptions {
        case caseInsensitive
    }

    /// Find first occurrence of pattern in array
    func firstRange(of pattern: ContiguousArray<UInt8>, options: SearchOptions? = nil) -> Range<Int>? {
        guard !pattern.isEmpty, pattern.count <= self.count else { return nil }

        let caseInsensitive = options == .caseInsensitive

        for i in 0...(count - pattern.count) {
            var matches = true
            for j in 0..<pattern.count {
                let selfByte = caseInsensitive ? self[i + j].lowercased : self[i + j]
                let patternByte = caseInsensitive ? pattern[j].lowercased : pattern[j]
                if selfByte != patternByte {
                    matches = false
                    break
                }
            }
            if matches {
                return i..<(i + pattern.count)
            }
        }
        return nil
    }
}

extension UInt8 {
    /// Simple ASCII lowercase conversion
    var lowercased: UInt8 {
        if self >= 65 && self <= 90 { // A-Z
            return self + 32
        }
        return self
    }
}
