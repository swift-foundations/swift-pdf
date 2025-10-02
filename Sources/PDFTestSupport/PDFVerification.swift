//
//  PDFVerification.swift
//  PDFTestSupport
//
//  Basic PDF verification utilities for testing
//

import Foundation

#if canImport(PDFKit)
import PDFKit

/// Verify that a PDF file exists and can be loaded
///
/// Usage:
/// ```swift
/// let url = try await pdf.render.client.html(html, to: output)
/// let doc = try verifyPDFExists(at: url)
/// #expect(doc.pageCount == 1)
/// ```
///
/// - Parameter url: The file URL where the PDF should exist
/// - Returns: A loaded PDFDocument ready for inspection
/// - Throws: TestError if the file doesn't exist or cannot be loaded as a PDF
public func verifyPDFExists(at url: URL) throws -> PDFDocument {
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw TestError.pdfNotFound(url)
    }

    guard let doc = PDFDocument(url: url) else {
        throw TestError.cannotLoadPDF(url)
    }

    return doc
}

/// Test errors for PDF verification
public enum TestError: Error, CustomStringConvertible {
    case pdfNotFound(URL)
    case cannotLoadPDF(URL)

    public var description: String {
        switch self {
        case .pdfNotFound(let url):
            return "PDF not found at: \(url.path)"
        case .cannotLoadPDF(let url):
            return "Cannot load PDF at: \(url.path)"
        }
    }
}

#endif
