import PDF
import Testing

extension Test.Snapshot.Strategy where Value == PDF.Document, Format == Swift.String {

    static var pdfStructure: Self {
        Test.Snapshot.Strategy<Swift.String, Swift.String>.lines.pullback {
            (document: PDF.Document) -> Swift.String in
            var lines: [Swift.String] = []

            lines.append("Pages: \(document.pages.count)")
            lines.append("")

            for (i, page) in document.pages.enumerated() {
                let pageNumber = i + 1
                let contentBytes = page.contents.reduce(0) { $0 + $1.data.count }
                let fontCount = page.resources.fonts.count
                let annotationCount = page.annotations.count

                var parts: [Swift.String] = ["Page \(pageNumber): \(contentBytes) content bytes"]
                if fontCount > 0 { parts.append("\(fontCount) fonts") }
                if annotationCount > 0 { parts.append("\(annotationCount) annotations") }
                lines.append(parts.joined(separator: ", "))
            }

            if let outline = document.outline {
                lines.append("")
                lines.append("Outline:")
                appendOutline(outline.items, to: &lines, indent: 1)
            }

            return lines.joined(separator: "\n")
        }
    }
}

private func appendOutline(
    _ items: [ISO_32000.Outline.Item],
    to lines: inout [Swift.String],
    indent: Int
) {
    let prefix = Swift.String(repeating: "  ", count: indent)
    for item in items {
        lines.append("\(prefix)- \(item.title)")
        if !item.children.isEmpty {
            appendOutline(item.children, to: &lines, indent: indent + 1)
        }
    }
}
