//
//  HtmlToPdfTests.swift
//  swift-html-to-pdf
//
//  Tests for HtmlToPdf target (swift-html integration)
//

import Testing
import HtmlToPdf
import PointFreeHTML

@Suite("PDF swift-html Integration Tests")
struct HtmlToPdfTests {

    @Test("PDF.Document can be created from HTMLRaw")
    func documentFromHTML() {
        let page = HTMLRaw("<div>Test content</div>")
        let url = URL(fileURLWithPath: "/tmp/test.pdf")
        let doc = PDF.Document(html: page, destination: url)

        #expect(doc.destination == url)
        #expect(doc.html.count > 0)
    }

    @Test("PDF.Document HTML init renders correctly")
    func htmlRenderingWorks() {
        let page = HTMLRaw("<html><body><h1>Hello</h1><p>World</p></body></html>")

        let url = URL(fileURLWithPath: "/tmp/test.pdf")
        let doc = PDF.Document(html: page, destination: url)

        let htmlString = String(decoding: Data(doc.html), as: UTF8.self)
        #expect(htmlString.contains("Hello"))
        #expect(htmlString.contains("World"))
    }

    @Test("PDF.Document with title creates correct path")
    func documentWithTitle() {
        let page = HTMLRaw("<div>Content</div>")
        let dir = URL(fileURLWithPath: "/tmp")
        let doc = PDF.Document(html: page, title: "My Report", in: dir)

        // Verify the filename and parent directory
        #expect(doc.destination.lastPathComponent == "My Report.pdf")
        #expect(doc.destination.deletingLastPathComponent().path.hasSuffix("tmp"))
    }
}
