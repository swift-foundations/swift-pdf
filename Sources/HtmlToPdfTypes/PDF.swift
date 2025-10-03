//
//  PDF.swift
//  swift-html-to-pdf
//
//  Core namespace for PDF rendering operations
//

import Dependencies
import Foundation

/// PDF domain containing rendering capability
///
/// This type serves as the unified entry point for all PDF operations,
/// following the domain-first pattern where the business capability (Render)
/// is primary with technical implementations (Client, Configuration) as nested types.
///
/// ## Basic Usage
///
/// ```swift
/// @Dependency(\.pdf) var pdf
///
/// // Render documents
/// try await pdf.render.client.documents(documents)
///
/// // Render single HTML to file
/// try await pdf.render.client.html(html, destination)
///
/// // Configure and render
/// try await withDependencies {
///     $0.pdf.render.configuration.paperSize = .letter
///     $0.pdf.render.configuration.margins = .wide
/// } operation: {
///     try await pdf.render.client.documents(documents)
/// }
/// ```
///
/// ## Direct Access
///
/// ```swift
/// @Dependency(\.pdf.render.client) var renderClient
/// @Dependency(\.pdf.render.configuration) var config
///
/// // Access client directly
/// let stream = try await renderClient.documents(documents)
///
/// // Access configuration directly
/// let poolSize = config.concurrency
/// ```
///
/// ## Convenience Methods for Configuration
///
/// ```swift
/// @Dependency(\.pdf) var pdf
///
/// // Set baseURL for resolving relative resources
/// try await pdf.withBaseURL(
///     URL(fileURLWithPath: "/path/to/assets"),
///     render: htmlWithRelativeImages,
///     to: output
/// )
/// ```
public struct PDF: Sendable {
    /// Rendering capability containing client and configuration
    public var render: Render

    public init(
        render: Render
    ) {
        self.render = render
    }
}

// MARK: - Dependency Registration
// DependencyKey conformances and DependencyValues extension are in HtmlToPdfLive target

