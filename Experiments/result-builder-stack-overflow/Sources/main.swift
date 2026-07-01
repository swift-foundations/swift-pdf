// MARK: - Result Builder Stack Overflow with PDF Pipeline
// Purpose: Reproduce ___chkstk_darwin when PDF.Document renders a view
//          with 70+ top-level HTML elements in async context
// Hypothesis: The PDF rendering pipeline (renderHTMLView → renderBody →
//             body.getter) adds enough stack depth that large view bodies
//             overflow the async task stack
//
// Toolchain: Swift 6.2 (Xcode 26.0)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — All variants pass in both sync and async Task contexts.
//         The crash is specific to Swift Testing framework's deeper call stack.
//         Standalone executables have sufficient stack for 70+ elements.
// Date: 2026-03-11

import Foundation
import PDF

// MARK: - Force evaluation
@inline(never)
func blackhole<T>(_ value: T) {
    withUnsafePointer(to: value) { _ in }
}

// MARK: - Variant 1: 30 elements through PDF pipeline
// Result: CONFIRMED — passes in both sync and async

struct PDFView30: HTML.View {
    var body: some HTML.View {
        H1 { "Title" }
        Paragraph { "P" }
        H1 { "1" }; Paragraph { "P" }
        H1 { "2" }; Paragraph { "P" }
        H2 { "2.1" }; Paragraph { "P" }
        H2 { "2.2" }; Paragraph { "P" }
        H1 { "3" }; Paragraph { "P" }
        H2 { "3.1" }; Paragraph { "P" }
        H2 { "3.2" }; Paragraph { "P" }
        H3 { "3.2.1" }; Paragraph { "P" }
        H3 { "3.2.2" }; Paragraph { "P" }
        H1 { "4" }; Paragraph { "P" }
        H2 { "4.1" }; Paragraph { "P" }
        H2 { "4.2" }; Paragraph { "P" }
        H1 { "5" }; Paragraph { "P" }
    }
}

// MARK: - Variant 2: 50 elements through PDF pipeline
// Result: CONFIRMED — passes in both sync and async

struct PDFView50: HTML.View {
    var body: some HTML.View {
        H1 { "T" }; Paragraph { "P" }
        H1 { "1" }; Paragraph { "P" }
        H1 { "2" }; Paragraph { "P" }
        H2 { "2.1" }; Paragraph { "P" }
        H2 { "2.2" }; Paragraph { "P" }
        H1 { "3" }; Paragraph { "P" }
        H2 { "3.1" }; Paragraph { "P" }
        H2 { "3.2" }; Paragraph { "P" }
        H3 { "3.2.1" }; Paragraph { "P" }
        H3 { "3.2.2" }; Paragraph { "P" }
        H1 { "4" }; Paragraph { "P" }
        H2 { "4.1" }; Paragraph { "P" }
        H2 { "4.2" }; Paragraph { "P" }
        H2 { "4.3" }; Paragraph { "P" }
        H3 { "4.3.1" }; Paragraph { "P" }
        H3 { "4.3.2" }; Paragraph { "P" }
        H1 { "5" }; Paragraph { "P" }
        H2 { "5.1" }; Paragraph { "P" }
        H2 { "5.2" }; Paragraph { "P" }
        H1 { "6" }; Paragraph { "P" }
        H2 { "6.1" }; Paragraph { "P" }
        H2 { "6.2" }; Paragraph { "P" }
        H3 { "6.2.1" }; Paragraph { "P" }
        H3 { "6.2.2" }; Paragraph { "P" }
        H1 { "7" }; Paragraph { "P" }
    }
}

// MARK: - Variant 3: 70 elements (matches TechnicalSpecificationView)
// Result: CONFIRMED — passes in both sync and async
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL CRASHES

struct PDFView70: HTML.View {
    var body: some HTML.View {
        H1 { "Technical Specification XYZ-2024" }
        Paragraph { "A comprehensive guide." }
        H1 { "1 Scope" }
        Paragraph { "Requirements for XYZ." }
        H1 { "2 Normative references" }
        Paragraph { "Referenced documents." }
        H1 { "3 Terms and definitions" }
        Paragraph { "Terms apply." }
        H1 { "4 Notation" }
        Paragraph { "Notation conventions." }
        H2 { "4.1 General" }
        Paragraph { "General notation." }
        H2 { "4.2 Established notations" }
        Paragraph { "Industry notations." }
        H2 { "4.3 Special symbols" }
        Paragraph { "Special symbols." }
        H3 { "4.3.1 Mathematical symbols" }
        Paragraph { "Math expressions." }
        H3 { "4.3.2 Logical symbols" }
        Paragraph { "Logical operations." }
        H1 { "5 Version designations" }
        Paragraph { "Version designations." }
        H1 { "6 Conformance" }
        Paragraph { "Conformance requirements." }
        H2 { "6.1 Conformance levels" }
        Paragraph { "Conformance levels." }
        H3 { "6.1.1 Basic conformance" }
        Paragraph { "Basic requirements." }
        H3 { "6.1.2 Full conformance" }
        Paragraph { "Full requirements." }
        H4 { "6.1.2.1 Mandatory features" }
        Paragraph { "Mandatory features." }
        H4 { "6.1.2.2 Optional features" }
        Paragraph { "Optional features." }
        H2 { "6.2 Conformance testing" }
        Paragraph { "Conformance testing." }
        H1 { "7 Syntax" }
        Paragraph { "XYZ syntax." }
        H2 { "7.1 Lexical elements" }
        Paragraph { "Lexical elements." }
        H2 { "7.2 Expressions" }
        Paragraph { "Expressions." }
        H2 { "7.3 Statements" }
        Paragraph { "Statements." }
        H1 { "8 Graphics" }
        Paragraph { "Graphics." }
        H2 { "8.1 Coordinate systems" }
        Paragraph { "Coordinates." }
        H2 { "8.2 Transformations" }
        Paragraph { "Transforms." }
        H1 { "9 Text" }
        Paragraph { "Text handling." }
        H2 { "9.1 General" }
        Paragraph { "Overview." }
        H2 { "9.2 Organisation and use of fonts" }
        Paragraph { "Font usage." }
        H3 { "9.2.1 Font types" }
        Paragraph { "Font types." }
        H3 { "9.2.2 Font embedding" }
        Paragraph { "Font embedding." }
        H2 { "9.3 Text state parameters and operators" }
        Paragraph { "Text state." }
        H2 { "9.4 Text objects" }
        Paragraph { "Text objects." }
        H2 { "9.5 Introduction to font data structures" }
        Paragraph { "Font structures." }
        H2 { "9.6 Simple fonts" }
        Paragraph { "Simple fonts." }
        H3 { "9.6.1 Type 1 fonts" }
        Paragraph { "Type 1." }
        H3 { "9.6.2 TrueType fonts" }
        Paragraph { "TrueType." }
        H2 { "9.7 Composite fonts" }
        Paragraph { "Composite." }
        H2 { "9.8 Font descriptors" }
        Paragraph { "Descriptors." }
        H1 { "Annex A (normative) Implementation notes" }
        Paragraph { "Implementation notes." }
        H1 { "Annex B (informative) Examples" }
        Paragraph { "Examples." }
        H2 { "B.1 Basic example" }
        Paragraph { "Basic example." }
        H2 { "B.2 Advanced example" }
        Paragraph { "Advanced example." }
    }
}

// MARK: - Execution

@main
struct Main {
    static func main() async {
        print("=== SYNC: PDF.Document rendering ===")

        print("  PDFView30...", terminator: "")
        let doc30 = PDF.Document { PDFView30() }
        blackhole(doc30)
        print(" OK (\(doc30.pages.count) pages)")

        print("  PDFView50...", terminator: "")
        let doc50 = PDF.Document { PDFView50() }
        blackhole(doc50)
        print(" OK (\(doc50.pages.count) pages)")

        print("  PDFView70...", terminator: "")
        let doc70 = PDF.Document { PDFView70() }
        blackhole(doc70)
        print(" OK (\(doc70.pages.count) pages)")

        print("\n=== ASYNC: PDF.Document rendering (Task) ===")

        print("  PDFView30...", terminator: "")
        let r30 = await Task { @Sendable in
            let doc = PDF.Document { PDFView30() }
            return doc.pages.count
        }.value
        print(" OK (\(r30) pages)")

        print("  PDFView50...", terminator: "")
        let r50 = await Task { @Sendable in
            let doc = PDF.Document { PDFView50() }
            return doc.pages.count
        }.value
        print(" OK (\(r50) pages)")

        print("  PDFView70...", terminator: "")
        let r70 = await Task { @Sendable in
            let doc = PDF.Document { PDFView70() }
            return doc.pages.count
        }.value
        print(" OK (\(r70) pages)")

        print("\n=== Results Summary ===")
        print("If any test above crashed, you'll see output truncated before 'OK'.")
    }
}
