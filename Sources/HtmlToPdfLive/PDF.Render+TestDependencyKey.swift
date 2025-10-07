//
//  PDF.Render+TestDependencyKey.swift
//  swift-html-to-pdf
//
//  Test dependency configuration for PDF.Render
//

import Dependencies

extension PDF.Render: TestDependencyKey {
    /// Test value that uses live client and configuration with isolated metrics
    ///
    /// Each test gets:
    /// - Real rendering client (.macOS/.iOS depending on platform) for integration testing
    /// - Real configuration (.default) for accurate behavior
    /// - Isolated metrics (.testValue) that bootstrap fresh backend per test
    ///
    /// This provides realistic testing while ensuring perfect metrics isolation.
    public static var testValue: Self {
        var testClient: PDF.Render.Client {
            #if os(macOS)
            return .macOS
            #elseif os(iOS)
            return .iOS
            #else
            return .testValue
            #endif
        }
        
        return PDF.Render(
            client: testClient,
            configuration: .default,
            metrics: .testValue
        )
    }
}

extension PDF.Render.Client: TestDependencyKey {
    public static let testValue = PDF.Render.Client()
}

extension PDF.Render.Metrics: TestDependencyKey {
    /// Test value that silently ignores all metric operations (no-op)
    ///
    /// This allows tests to run without triggering unimplemented errors.
    /// For testing with metrics observation, bootstrap TestMetricsBackend from PDFTestSupport:
    ///
    /// ```swift
    /// let backend = TestMetricsBackend()
    /// MetricsSystem.bootstrap(backend)
    ///
    /// // Run code that records metrics
    /// try await pdf.render(html: html, to: url)
    ///
    /// // Query backend directly
    /// #expect(backend.counters["htmltopdf_pdfs_generated_total"]?.value == 1)
    /// ```
    public static let testValue = PDF.Render.Metrics(
        incrementPDFsGenerated: {},
        incrementPDFsFailed: {},
        incrementPoolReplacements: {},
        recordRenderDuration: { _, _ in },
        updatePoolUtilization: { _ in },
        updateThroughput: { _ in },
        recordPoolAcquisitionTime: { _ in },
        recordWebViewRenderTime: { _ in },
        recordCSSInjectionTime: { _ in },
        recordDataConversionTime: { _ in }
    )
}
