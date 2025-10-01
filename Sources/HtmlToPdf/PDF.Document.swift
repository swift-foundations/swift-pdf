//
//  PDF.Document.swift
//  swift-html-to-pdf
//
//  Document model for PDF rendering
//

import Foundation

extension PDF {
    /// A document to be rendered as a PDF
    ///
    /// Example:
    /// ```swift
    /// let document = PDF.Document(
    ///     html: "<html><body>Hello</body></html>",
    ///     destination: fileURL
    /// )
    /// ```
    public struct Document: Sendable {
        public let html: String
        public let destination: URL

        public init(html: String, destination: URL) {
            self.html = html
            self.destination = destination
        }

        public init(html: String, title: String, in directory: URL) {
            self.html = html
            self.destination = directory
                .appendingPathComponent(title.replacingSlashesWithDivisionSlash())
                .appendingPathExtension("pdf")
        }
    }
}

// MARK: - String Utilities

extension String {
    func replacingSlashesWithDivisionSlash() -> String {
        let divisionSlash = "\u{2215}" // Unicode for Division Slash (∕)
        return self.replacingOccurrences(of: "/", with: divisionSlash)
    }

    /// Injects CSS into HTML, either before </head> or at the beginning if no head tag exists
    func injectingCSS(_ css: String) -> String {
        // Try to inject before </head>
        if let headEndRange = self.range(of: "</head>", options: .caseInsensitive) {
            return self.replacingCharacters(in: headEndRange, with: css + "</head>")
        }
        // Try to inject after <head>
        else if let headStartRange = self.range(of: "<head>", options: .caseInsensitive) {
            // Find the end of the <head> tag (after any attributes)
            if let tagEnd = self.range(of: ">", options: [], range: headStartRange.upperBound..<self.endIndex) {
                let insertPoint = self.index(after: tagEnd.lowerBound)
                return String(self[..<insertPoint]) + css + String(self[insertPoint...])
            } else {
                // If we can't find the closing >, just append after <head
                return self.replacingOccurrences(of: "<head>", with: "<head>" + css, options: .caseInsensitive)
            }
        }
        // Try to inject before <body>
        else if let bodyRange = self.range(of: "<body", options: .caseInsensitive) {
            return String(self[..<bodyRange.lowerBound]) + css + String(self[bodyRange.lowerBound...])
        }
        // Otherwise inject at the beginning
        else {
            return css + self
        }
    }

    /// Determines if the HTML string contains any `<img>` tags
    func containsImages() -> Bool {
        let pattern = "(?i)<img\\s+[^>]*src\\s*=\\s*[\"']([^\"']*?)[\"'][^>]*>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return false
        }
        let range = NSRange(location: 0, length: self.utf16.count)
        return regex.firstMatch(in: self, options: [], range: range) != nil
    }
}
