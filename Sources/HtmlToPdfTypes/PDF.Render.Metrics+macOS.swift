//
//  PDF.Render.Metrics+macOS.swift
//  swift-html-to-pdf
//
//  Live metrics implementation using swift-metrics
//

#if os(macOS) || os(iOS)
import Dependencies
import Metrics

extension PDF.Render.Metrics: DependencyKey {
    /// Live implementation delegating to swift-metrics
    ///
    /// Creates swift-metrics Counter/Timer/Gauge instances and delegates
    /// operations to them. Requires MetricsSystem.bootstrap() at app startup.
    public static var liveValue: Self {
        // Create swift-metrics instances (captured in closures)
        let pdfsGenerated = Counter(label: "htmltopdf_pdfs_generated_total")
        let pdfsFailed = Counter(label: "htmltopdf_pdfs_failed_total")
        let poolReplacements = Counter(label: "htmltopdf_pool_replacements_total")
        let renderDuration = Timer(label: "htmltopdf_render_duration_seconds")
        let poolUtilization = Gauge(label: "htmltopdf_pool_utilization")
        let currentThroughput = Gauge(label: "htmltopdf_throughput_pdfs_per_sec")

        return Self(
            incrementPDFsGenerated: { pdfsGenerated.increment() },
            incrementPDFsFailed: { pdfsFailed.increment() },
            incrementPoolReplacements: { poolReplacements.increment() },
            recordRenderDuration: { duration, mode in
                let nanoseconds = duration.components.seconds * 1_000_000_000 +
                                duration.components.attoseconds / 1_000_000_000
                if let mode = mode {
                    Timer(
                        label: "htmltopdf_render_duration_seconds",
                        dimensions: [("mode", mode.metricsLabel)]
                    ).recordNanoseconds(nanoseconds)
                } else {
                    renderDuration.recordNanoseconds(nanoseconds)
                }
            },
            updatePoolUtilization: { count in poolUtilization.record(count) },
            updateThroughput: { pdfsPerSecond in currentThroughput.record(pdfsPerSecond) }
        )
    }
}
#endif
