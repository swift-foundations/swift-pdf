// PDF.Debug.Crash.swift

import PDF
import Testing

@Suite struct DebugCrashInvestigation {

    @Test func fontCopyDestroyCycle() {
        var font = PDF.Font.helvetica
        for _ in 0..<100 {
            font = font.bold
            font = font.italic
            font = font.regular
        }
        #expect(font.weight == .regular)
    }

    @Test func nestedInoutFontAssignment() {
        struct Inner { var font: PDF.Font = .helvetica }
        struct Middle { var style: Inner = .init() }
        struct Outer { var pdf: Middle = .init() }
        var context = Outer()
        context.pdf.style.font = context.pdf.style.font.bold
        #expect(context.pdf.style.font.weight == .bold)
    }

    @Test func markdownPlain() {
        let doc = PDF.Document(info: .init(title: "T", author: "T")) {
            p { "Hello" }
        }
        #expect(doc.pages.count >= 1)
    }

    @Test func markdownHeading() {
        let doc = PDF.Document(info: .init(title: "T", author: "T")) {
            Markdown { "# Heading" }
        }
        #expect(doc.pages.count >= 1)
    }
}
