// Pipeline Analysis.swift

import HTML
import PDF
import Testing

// MARK: - Pipeline Micro-benchmarks

extension PDF.Test.Performance {

    // MARK: - Raw PDF.Text (no HTML pipeline)

    @Test(.timed(iterations: 100, warmup: 10))
    func `raw PDF.Text 5 paragraphs`() {
        let doc = PDF.Document {
            PDF.Text("This is a test paragraph with some content to make it realistic.")
            PDF.Text("This is paragraph 2 with some content to make it realistic.")
            PDF.Text("This is paragraph 3 with some content to make it realistic.")
            PDF.Text("This is paragraph 4 with some content to make it realistic.")
            PDF.Text("This is paragraph 5 with some content to make it realistic.")
        }
        let _ = [UInt8](doc)
    }

    // MARK: - HTML Paragraph at Various Scales

    @Test(.timed(iterations: 100, warmup: 10))
    func `HTML pipeline 5 paragraphs`() {
        makePDF(paragraphs: 5)
    }

    @Test(.timed(iterations: 20, warmup: 2))
    func `HTML pipeline 50 paragraphs`() {
        makePDF(paragraphs: 50)
    }

    @Test(.timed(iterations: 10, warmup: 1))
    func `HTML pipeline 100 paragraphs`() {
        makePDF(paragraphs: 100)
    }

    // MARK: - Direct PDF.Text at Various Scales

    @Test(.timed(iterations: 100, warmup: 10))
    func `direct PDF.Text 5 paragraphs`() {
        makePDFDirect(paragraphs: 5)
    }

    @Test(.timed(iterations: 20, warmup: 2))
    func `direct PDF.Text 50 paragraphs`() {
        makePDFDirect(paragraphs: 50)
    }

    @Test(.timed(iterations: 10, warmup: 1))
    func `direct PDF.Text 100 paragraphs`() {
        makePDFDirect(paragraphs: 100)
    }
}

// MARK: - Helpers

private func makePDFDirect(paragraphs: Int) {
    let doc = PDF.Document {
        PDF.Text("Test Document")
        for _ in 0..<paragraphs {
            PDF.Text("This is a paragraph with some content to make it realistic.")
        }
    }
    let _ = [UInt8](doc)
}
