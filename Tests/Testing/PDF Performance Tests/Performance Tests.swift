import HTML
import PDF
import Testing

extension PDF {
    #Tests
}

extension PDF.Test.Performance {

    @Test(.timed(iterations: 50, warmup: 5))
    func `paragraphs 1`() {
        makePDF(paragraphs: 1)
    }

    @Test(.timed(iterations: 20, warmup: 2))
    func `paragraphs 10`() {
        makePDF(paragraphs: 10)
    }

    @Test(.timed(iterations: 10, warmup: 1))
    func `paragraphs 50`() {
        makePDF(paragraphs: 50)
    }

    @Test(.timed(iterations: 5, warmup: 1))
    func `paragraphs 100`() {
        makePDF(paragraphs: 100)
    }

    @Test(.timed(iterations: 3, warmup: 1))
    func `paragraphs 200`() {
        makePDF(paragraphs: 200)
    }

    @Test(.timed(iterations: 2, warmup: 1))
    func `paragraphs 500`() {
        makePDF(paragraphs: 500)
    }

    @Test(.timed(iterations: 500, warmup: 50))
    func `throughput 1 paragraph`() {
        makePDF(paragraphs: 1)
    }

    @Test(.timed(iterations: 100, warmup: 10))
    func `throughput 10 paragraphs`() {
        makePDF(paragraphs: 10)
    }

    @Test(.timed(iterations: 20, warmup: 2))
    func `throughput 50 paragraphs`() {
        makePDF(paragraphs: 50)
    }

    @Test(.timed(iterations: 10, warmup: 1))
    func `throughput 100 paragraphs`() {
        makePDF(paragraphs: 100)
    }

    @Test(.timed(iterations: 2, warmup: 1))
    func `throughput 500 paragraphs`() {
        makePDF(paragraphs: 500)
    }

    @Test(.timed(iterations: 10, warmup: 2))
    func `batch 10 documents`() {
        for i in 0..<10 {
            let doc = PDF.Document {
                H1 { "Document \(i)" }
                Paragraph { "This is test document number \(i)." }
            }
            let _ = [UInt8](doc)
        }
    }
}

func makePDF(paragraphs: Int) {
    switch paragraphs {
    case 1:
        let doc = PDF.Document { Doc1() }
        let _ = [UInt8](doc)

    case 10:
        let doc = PDF.Document { Doc10() }
        let _ = [UInt8](doc)

    case 50:
        let doc = PDF.Document { Doc50() }
        let _ = [UInt8](doc)

    case 100:
        let doc = PDF.Document { Doc100() }
        let _ = [UInt8](doc)

    case 200:
        let doc = PDF.Document { Doc200() }
        let _ = [UInt8](doc)

    case 500:
        let doc = PDF.Document { Doc500() }
        let _ = [UInt8](doc)

    default:
        let doc = PDF.Document { Doc1() }
        let _ = [UInt8](doc)
    }
}

struct Doc1: HTML.View {
    var body: some HTML.View {
        H1 { "Test Document" }
        Paragraph { "Paragraph with content." }
    }
}

struct Doc10: HTML.View {
    var body: some HTML.View {
        H1 { "Test Document" }
        Paragraph { "Paragraph 1" }
        Paragraph { "Paragraph 2" }
        Paragraph { "Paragraph 3" }
        Paragraph { "Paragraph 4" }
        Paragraph { "Paragraph 5" }
        Paragraph { "Paragraph 6" }
        Paragraph { "Paragraph 7" }
        Paragraph { "Paragraph 8" }
        Paragraph { "Paragraph 9" }
        Paragraph { "Paragraph 10" }
    }
}

struct Para10: HTML.View {
    var body: some HTML.View {
        Paragraph { "Paragraph 1" }
        Paragraph { "Paragraph 2" }
        Paragraph { "Paragraph 3" }
        Paragraph { "Paragraph 4" }
        Paragraph { "Paragraph 5" }
        Paragraph { "Paragraph 6" }
        Paragraph { "Paragraph 7" }
        Paragraph { "Paragraph 8" }
        Paragraph { "Paragraph 9" }
        Paragraph { "Paragraph 10" }
    }
}

struct Doc50: HTML.View {
    var body: some HTML.View {
        H1 { "Test Document" }
        Para10()
        Para10()
        Para10()
        Para10()
        Para10()
    }
}

struct Doc100: HTML.View {
    var body: some HTML.View {
        H1 { "Test Document" }
        Para10()
        Para10()
        Para10()
        Para10()
        Para10()
        Para10()
        Para10()
        Para10()
        Para10()
        Para10()
    }
}

struct Para100: HTML.View {
    var body: some HTML.View {
        Para10()
        Para10()
        Para10()
        Para10()
        Para10()
        Para10()
        Para10()
        Para10()
        Para10()
        Para10()
    }
}

struct Doc200: HTML.View {
    var body: some HTML.View {
        H1 { "Test Document" }
        Para100()
        Para100()
    }
}

struct Doc500: HTML.View {
    var body: some HTML.View {
        H1 { "Test Document" }
        Para100()
        Para100()
        Para100()
        Para100()
        Para100()
    }
}
