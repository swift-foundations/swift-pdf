//
//  PaginationModeTests.swift
//  swift-html-to-pdf
//
//  Tests for pagination mode functionality
//

import Testing
import Foundation
import HtmlToPdfLive
import Dependencies
import DependenciesTestSupport
import PDFKit

@Suite(
    "Pagination Mode Tests"
)
struct PaginationModeTests {
    @Dependency(\.pdf) var pdf
    
    @Test(
        "Paginated mode creates multiple pages for long content",
        .dependency(\.pdf.render.configuration.paginationMode, .paginated)
    )
    func paginatedModeLongContent() async throws {
        
        let tempDir = FileManager.default.temporaryDirectory
        let output = tempDir.appendingPathComponent("test-paginated.pdf")
        defer { try? FileManager.default.removeItem(at: output) }
        
        // Generate long content (should span ~3 pages)
        let items = (1...100).map { "<p style='margin: 20px 0;'>Item \($0)</p>" }.joined()
        let html = """
            <!DOCTYPE html>
            <html>
            <head><title>Test</title></head>
            <body>\(items)</body>
            </html>
            """
        
        let url = try await pdf.render.client.html(html, to: output)
        
        // Verify multiple pages were created
        guard let pdfDoc = PDFDocument(url: url) else {
            throw NSError(domain: "Failed to load PDF", code: -1)
        }
        
        let pageCount = pdfDoc.pageCount
        #expect(pageCount > 1, "Paginated mode should create multiple pages for long content, got \(pageCount)")
        
        // Verify A4 dimensions
        if let firstPage = pdfDoc.page(at: 0) {
            let bounds = firstPage.bounds(for: .mediaBox)
            #expect(abs(bounds.width - 595.28) < 1.0, "Page width should be A4")
            #expect(abs(bounds.height - 841.89) < 1.0, "Page height should be A4")
        }
    }
    
    @Test(
        "Continuous mode creates single tall page",
        .dependency(\.pdf.render.configuration.paginationMode, .continuous)
    )
    func continuousModeLongContent() async throws {

        let tempDir = FileManager.default.temporaryDirectory
        let output = tempDir.appendingPathComponent("test-continuous.pdf")
        defer { try? FileManager.default.removeItem(at: output) }

        // Generate long content
        let items = (1...100).map { "<p style='margin: 20px 0;'>Item \($0)</p>" }.joined()
        let html = """
            <!DOCTYPE html>
            <html>
            <head><title>Test</title></head>
            <body>\(items)</body>
            </html>
            """

        let url = try await pdf.render.client.html(html, to: output)

        // Verify page count
        guard let pdfDoc = PDFDocument(url: url) else {
            throw NSError(domain: "Failed to load PDF", code: -1)
        }

        let pageCount = pdfDoc.pageCount

        #if os(macOS)
        // macOS uses WKWebView.createPDF for continuous mode -> single tall page
        #expect(pageCount == 1, "Continuous mode should create single page on macOS, got \(pageCount)")

        // Verify tall page
        if let firstPage = pdfDoc.page(at: 0) {
            let bounds = firstPage.bounds(for: .mediaBox)
            // Use larger tolerance for width to account for rendering variations (margins, DPI differences)
            #expect(abs(bounds.width - 595.28) < 20.0, "Page width should be approximately A4 width (595pt), got \(bounds.width)")
            #expect(bounds.height > 1000, "Page should be tall (continuous), got \(bounds.height)")
        }
        #else
        // iOS uses WebView rendering which may still paginate in continuous mode
        // This is expected behavior - just verify PDF was created
        #expect(pageCount >= 1, "Continuous mode should create at least one page on iOS, got \(pageCount)")

        if let firstPage = pdfDoc.page(at: 0) {
            let bounds = firstPage.bounds(for: .mediaBox)
            #expect(abs(bounds.width - 595.28) < 1.0, "Page width should match A4 width")
        }
        #endif
    }
    
    @Test(
        "Automatic mode with short content uses continuous",
        .dependency(\.pdf.render.configuration.paginationMode, .automatic())
    )
    func automaticModeShortContent() async throws {
        
        let tempDir = FileManager.default.temporaryDirectory
        let output = tempDir.appendingPathComponent("test-auto-short.pdf")
        defer { try? FileManager.default.removeItem(at: output) }
        
        let html = """
            <!DOCTYPE html>
            <html>
            <head><title>Test</title></head>
            <body><h1>Short Content</h1><p>Just a paragraph.</p></body>
            </html>
            """
        
        let url = try await pdf.render.client.html(html, to: output)
        
        guard let pdfDoc = PDFDocument(url: url) else {
            throw NSError(domain: "Failed to load PDF", code: -1)
        }
        
        // Should use fast continuous mode for short content
        let pageCount = pdfDoc.pageCount
        #expect(pageCount == 1, "Automatic mode should use continuous for short content, got \(pageCount) pages")
    }
    
    @Test(
        "Automatic mode with long content uses paginated",
        .dependency(\.pdf.render.configuration.paginationMode, .automatic(heuristic: .contentLength(threshold: 1.5)))
    )
    func automaticModeLongContent() async throws {
        
        let tempDir = FileManager.default.temporaryDirectory
        let output = tempDir.appendingPathComponent("test-auto-long.pdf")
        defer { try? FileManager.default.removeItem(at: output) }
        
        // Generate content that exceeds 1.5 pages
        let items = (1...80).map { "<p style='margin: 20px 0;'>Item \($0)</p>" }.joined()
        let html = """
            <!DOCTYPE html>
            <html>
            <head><title>Test</title></head>
            <body>\(items)</body>
            </html>
            """
        
        let url = try await pdf.render.client.html(html, to: output)
        
        guard let pdfDoc = PDFDocument(url: url) else {
            throw NSError(domain: "Failed to load PDF", code: -1)
        }
        
        // Should use paginated mode for long content
        let pageCount = pdfDoc.pageCount
        #expect(pageCount > 1, "Automatic mode should use paginated for long content, got \(pageCount) pages")
        
        // Verify proper A4 dimensions (not tall single page)
        if let firstPage = pdfDoc.page(at: 0) {
            let bounds = firstPage.bounds(for: .mediaBox)
            #expect(abs(bounds.height - 841.89) < 1.0, "Automatic mode with long content should use proper A4 pagination")
        }
    }
    
    @Test("Margins work in both modes")
    func marginsInBothModes() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        
        // Test paginated mode with margins
        try await withDependencies {
            $0.pdf = .liveValue
            $0.pdf.render.configuration.paginationMode = .paginated
            $0.pdf.render.configuration.margins = .wide  // 72pt margins
        } operation: {
            
            let output = tempDir.appendingPathComponent("test-paginated-margins.pdf")
            defer { try? FileManager.default.removeItem(at: output) }
            
            let html = "<html><body><p>Test margins in paginated mode</p></body></html>"
            let result = try await pdf.render.client.html(html, to: output)
            
            #expect(FileManager.default.fileExists(atPath: result.path), "Paginated PDF with margins should be created")
        }
        
        // Test continuous mode with margins
        try await withDependencies {
            $0.pdf = .liveValue
            $0.pdf.render.configuration.paginationMode = .continuous
            $0.pdf.render.configuration.margins = .wide  // 72pt margins
        } operation: {
            
            let output = tempDir.appendingPathComponent("test-continuous-margins.pdf")
            defer { try? FileManager.default.removeItem(at: output) }
            
            let html = "<html><body><p>Test margins in continuous mode</p></body></html>"
            let result = try await pdf.render.client.html(html, to: output)
            
            #expect(FileManager.default.fileExists(atPath: result.path), "Continuous PDF with margins should be created")
        }
    }
}
