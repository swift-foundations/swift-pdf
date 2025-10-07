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
    /// Creates Counter/Timer/Gauge lazily on each call to avoid bootstrap ordering issues.
    /// MetricsSystem backends cache handlers, so performance impact is minimal.
    public static var liveValue: Self {
        return Self(
            incrementPDFsGenerated: {
                Counter(label: "htmltopdf_pdfs_generated_total").increment()
            },
            incrementPDFsFailed: {
                Counter(label: "htmltopdf_pdfs_failed_total").increment()
            },
            incrementPoolReplacements: {
                Counter(label: "htmltopdf_pool_replacements_total").increment()
            },
            recordRenderDuration: { duration, mode in
                let nanoseconds = duration.components.seconds * 1_000_000_000 +
                                duration.components.attoseconds / 1_000_000_000
                if let mode = mode {
                    Timer(
                        label: "htmltopdf_render_duration_seconds",
                        dimensions: [("mode", mode.metricsLabel)]
                    ).recordNanoseconds(nanoseconds)
                } else {
                    Timer(label: "htmltopdf_render_duration_seconds")
                        .recordNanoseconds(nanoseconds)
                }
            },
            updatePoolUtilization: { count in
                Gauge(label: "htmltopdf_pool_utilization").record(count)
            },
            updateThroughput: { pdfsPerSecond in
                Gauge(label: "htmltopdf_throughput_pdfs_per_sec").record(pdfsPerSecond)
            },
            recordPoolAcquisitionTime: { duration in
                let nanoseconds = duration.components.seconds * 1_000_000_000 +
                                duration.components.attoseconds / 1_000_000_000
                Timer(label: "htmltopdf_pool_acquisition_seconds")
                    .recordNanoseconds(nanoseconds)
            },
            recordWebViewRenderTime: { duration in
                let nanoseconds = duration.components.seconds * 1_000_000_000 +
                                duration.components.attoseconds / 1_000_000_000
                Timer(label: "htmltopdf_webview_render_seconds")
                    .recordNanoseconds(nanoseconds)
            },
            recordCSSInjectionTime: { duration in
                let nanoseconds = duration.components.seconds * 1_000_000_000 +
                                duration.components.attoseconds / 1_000_000_000
                Timer(label: "htmltopdf_css_injection_seconds")
                    .recordNanoseconds(nanoseconds)
            },
            recordDataConversionTime: { duration in
                let nanoseconds = duration.components.seconds * 1_000_000_000 +
                                duration.components.attoseconds / 1_000_000_000
                Timer(label: "htmltopdf_data_conversion_seconds")
                    .recordNanoseconds(nanoseconds)
            }
        )
    }
}
#endif
