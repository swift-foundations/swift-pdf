//
//  PDF.PaginationMode.swift
//  swift-html-to-pdf
//
//  Pagination mode for PDF rendering
//

import Foundation

extension PDF {
    /// How content should be paginated in the PDF
    ///
    /// This determines how HTML content flows into the PDF:
    ///
    /// - `.paginated`: Content is split into multiple pages (e.g., 3 pages of A4)
    ///   - Best for: Invoices, reports, documents for printing
    ///   - Performance: 677 PDFs/sec (batch size 1,000 on M1)
    ///   - Implementation: Uses NSPrintOperation (macOS) or UIPrintPageRenderer (iOS)
    ///
    /// - `.continuous`: Single tall page containing all content
    ///   - Best for: Articles, web captures, infographics for screen viewing
    ///   - Performance: 1,939 PDFs/sec (batch size 1,000 on M1)
    ///   - Implementation: Uses WKWebView.createPDF
    ///
    /// - `.automatic`: Chooses based on content analysis
    ///   - Best for: Unknown content, balanced performance
    ///   - Performance: Varies based on detection
    public enum PaginationMode: Sendable, Equatable {
        /// Split content into multiple pages of exact paperSize
        ///
        /// Each page will match the configured `paperSize` exactly.
        /// CSS page breaks are respected.
        /// Margins are applied via print settings.
        case paginated
        
        /// Single continuous page
        ///
        /// Width matches `paperSize.width`, height matches content height.
        /// CSS page breaks are ignored.
        /// Margins are applied via CSS padding.
        case continuous
        
        /// Automatically choose based on content analysis
        ///
        /// Uses the provided heuristic to determine whether to use
        /// paginated or continuous mode.
        case automatic(heuristic: AutomaticHeuristic = .contentLength())
    }
}

extension PDF.PaginationMode {

    /// Strategy for automatic pagination detection
    public enum AutomaticHeuristic: Sendable, Equatable {
        /// Choose based on estimated page count
        ///
        /// Measures content height and compares to page height.
        /// If content would span more than the threshold (in pages), uses paginated mode.
        ///
        /// - Parameter threshold: Number of pages that triggers pagination (default: 1.5)
        ///
        /// Example: threshold of 1.5 means content over 1.5 pages uses paginated mode
        case contentLength(threshold: CGFloat = 1.5)

        /// Choose based on HTML structure
        ///
        /// Detects presence of print-specific CSS or page break directives.
        /// If found, uses paginated mode for proper print output.
        case htmlStructure

        /// Always prefer speed (continuous mode)
        ///
        /// Uses WKWebView.createPDF for maximum throughput.
        /// Results in continuous tall pages.
        case preferSpeed

        /// Always prefer print-ready output (paginated mode)
        ///
        /// Uses NSPrintOperation/UIPrintPageRenderer for proper pagination.
        /// Results in properly paginated documents.
        case preferPrintReady
    }
}

// MARK: - Metrics Support

extension PDF.PaginationMode {
    /// Label for metrics dimension tracking
    ///
    /// Provides a stable string representation for use in metrics dimensions.
    /// This allows segmentation of render duration metrics by pagination mode.
    package var metricsLabel: String {
        switch self {
        case .continuous:
            return "continuous"
        case .paginated:
            return "paginated"
        case .automatic(let heuristic):
            switch heuristic {
            case .contentLength:
                return "automatic_content_length"
            case .htmlStructure:
                return "automatic_html_structure"
            case .preferSpeed:
                return "automatic_prefer_speed"
            case .preferPrintReady:
                return "automatic_prefer_print_ready"
            }
        }
    }
}

// MARK: - Internal Rendering Method
extension PDF {
    /// Internal rendering method (not exposed in public API)
    ///
    /// This is the actual implementation strategy chosen after
    /// analyzing the pagination mode and content.
    package enum InternalRenderingMethod {
        case webView
        case printOperation
    }
}
