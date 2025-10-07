//
//  PDF.Render.Metrics.swift
//  swift-html-to-pdf
//
//  Metrics for PDF rendering observability
//

import Dependencies
import DependenciesMacros
import Foundation

extension PDF.Render {
    /// Metrics for PDF rendering operations
    ///
    /// Following the domain-first pattern where Metrics is a capability
    /// with operations defined as dependency endpoints for testability.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// @Dependency(\.pdf.render.metrics) var metrics
    ///
    /// metrics.recordSuccess(duration: duration, mode: .paginated)
    /// metrics.recordFailure(error: error)
    /// ```
    ///
    /// ## Production Integration
    ///
    /// The live implementation delegates to swift-metrics. Bootstrap once at startup:
    ///
    /// ```swift
    /// import Metrics
    ///
    /// @main
    /// struct MyApp {
    ///     static func main() {
    ///         MetricsSystem.bootstrap(PrometheusMetricsFactory())
    ///         // ...
    ///     }
    /// }
    /// ```
    ///
    /// ## Available Metrics
    ///
    /// **Counters:**
    /// - `htmltopdf_pdfs_generated_total`: Total PDFs successfully generated
    /// - `htmltopdf_pdfs_failed_total`: Total PDF generation failures
    /// - `htmltopdf_pool_replacements_total`: Total resource pool replacements
    ///
    /// **Timers:**
    /// - `htmltopdf_render_duration_seconds`: PDF render duration (p50/p95/p99)
    ///
    /// **Gauges:**
    /// - `htmltopdf_pool_utilization`: Current WebViews in pool
    /// - `htmltopdf_throughput_pdfs_per_sec`: Current throughput
    @DependencyClient
    public struct Metrics: @unchecked Sendable {
        
        // MARK: - Counter Operations
        
        /// Increment PDFs generated counter
        @DependencyEndpoint
        public var incrementPDFsGenerated: @Sendable () -> Void
        
        /// Increment PDFs failed counter
        @DependencyEndpoint
        public var incrementPDFsFailed: @Sendable () -> Void
        
        /// Increment pool replacements counter
        @DependencyEndpoint
        public var incrementPoolReplacements: @Sendable () -> Void
        
        // MARK: - Timer Operations
        
        /// Record render duration
        @DependencyEndpoint
        public var recordRenderDuration: @Sendable (_ duration: Duration, _ mode: PDF.PaginationMode?) -> Void
        
        // MARK: - Gauge Operations
        
        /// Update pool utilization gauge
        @DependencyEndpoint
        public var updatePoolUtilization: @Sendable (_ count: Int) -> Void
        
        /// Update throughput gauge
        @DependencyEndpoint
        public var updateThroughput: @Sendable (_ pdfsPerSecond: Double) -> Void
        
        // MARK: - Detailed Timing Operations
        
        /// Record pool acquisition time
        @DependencyEndpoint
        public var recordPoolAcquisitionTime: @Sendable (_ duration: Duration) -> Void
        
        /// Record WebView render time (total time in WebView including all operations)
        @DependencyEndpoint
        public var recordWebViewRenderTime: @Sendable (_ duration: Duration) -> Void
        
        /// Record CSS injection time
        @DependencyEndpoint
        public var recordCSSInjectionTime: @Sendable (_ duration: Duration) -> Void
        
        /// Record HTML data conversion time
        @DependencyEndpoint
        public var recordDataConversionTime: @Sendable (_ duration: Duration) -> Void
    }
}

extension PDF.Render.Metrics {
    // MARK: - Convenience Methods
    
    /// Record successful PDF generation
    ///
    /// Increments the counter and records the render duration.
    ///
    /// - Parameters:
    ///   - duration: Time taken to render the PDF
    ///   - mode: Optional pagination mode for dimensional tracking
    public func recordSuccess(duration: Duration, mode: PDF.PaginationMode? = nil) {
        incrementPDFsGenerated()
        recordRenderDuration(duration, mode)
    }
    
    /// Record PDF generation failure
    ///
    /// Increments the failures counter.
    ///
    /// - Parameter error: Optional error for dimensional tracking
    public func recordFailure(error: PrintingError? = nil) {
        incrementPDFsFailed()
    }
    
    /// Record pool replacement
    ///
    /// Increments the pool replacements counter.
    public func recordPoolReplacement() {
        incrementPoolReplacements()
    }
}

