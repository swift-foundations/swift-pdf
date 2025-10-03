//
//  HtmlToPdfTypesTests.swift
//  swift-html-to-pdf
//
//  Tests for HtmlToPdfTypes target (pure types, no implementation)
//

import Testing
import HtmlToPdfTypes

@Suite("PDF Types Tests")
struct HtmlToPdfTypesTests {

    @Test("PDF.Document can be created from string")
    func documentFromString() {
        let html = "<html><body>Test</body></html>"
        let url = URL(fileURLWithPath: "/tmp/test.pdf")
        let doc = PDF.Document(htmlString: html, destination: url)

        #expect(doc.destination == url)
        #expect(doc.html.count > 0)
    }

    @Test("PDF.Document can be created from bytes")
    func documentFromBytes() {
        let bytes = ContiguousArray("<html><body>Test</body></html>".utf8)
        let url = URL(fileURLWithPath: "/tmp/test.pdf")
        let doc = PDF.Document(htmlBytes: bytes, destination: url)

        #expect(doc.destination == url)
        #expect(doc.html == bytes)
    }

    @Test("PDF.Configuration has sensible defaults")
    func configurationDefaults() {
        let config = PDF.Configuration.default
        #expect(config.paperSize.width > 0)
        #expect(config.paperSize.height > 0)
    }
}
