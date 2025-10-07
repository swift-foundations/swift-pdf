//
//  PDF.Appearance.swift
//  swift-html-to-pdf
//
//  Color scheme appearance for PDF rendering
//

import Foundation

extension PDF {
    /// Color scheme appearance for PDF rendering
    ///
    /// Controls whether PDFs render with light or dark backgrounds, independent of system settings.
    ///
    /// ## Default Behavior
    ///
    /// The default is `.light`, which ensures professional documents (invoices, reports, contracts)
    /// render with white backgrounds and dark text regardless of macOS dark mode settings.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Default: Force light appearance (recommended for invoices, reports)
    /// try await pdf.render(html: html, to: url)
    ///
    /// // Respect system dark mode
    /// try await withDependencies {
    ///     $0.pdf.render.configuration.appearance = .auto
    /// } operation: {
    ///     try await pdf.render(html: html, to: url)
    /// }
    ///
    /// // Force dark appearance (rare - perhaps for dark-themed presentations)
    /// try await withDependencies {
    ///     $0.pdf.render.configuration.appearance = .dark
    /// } operation: {
    ///     try await pdf.render(html: html, to: url)
    /// }
    /// ```
    public enum Appearance: Sendable, Equatable {
        /// Force light appearance (white background, dark text)
        ///
        /// **Default and recommended for most use cases.**
        ///
        /// Ensures PDFs render with white backgrounds regardless of system dark mode setting.
        /// This is the expected appearance for professional documents:
        /// - Invoices and receipts
        /// - Reports and contracts
        /// - Business correspondence
        /// - Documents intended for printing
        ///
        /// ## CSS Injection
        ///
        /// When set, injects CSS to force light color scheme:
        /// ```css
        /// :root { color-scheme: light !important; }
        /// html, body { background-color: white !important; color: black !important; }
        /// ```
        case light

        /// Force dark appearance (dark background, light text)
        ///
        /// Ensures PDFs render with dark backgrounds regardless of system setting.
        ///
        /// **Rare use case** - typically only useful for:
        /// - Dark-themed presentations or slide decks
        /// - Screen-only documents with intentional dark design
        /// - Accessibility requirements (some users prefer dark backgrounds)
        ///
        /// **Not recommended for:**
        /// - Documents intended for printing (wastes ink)
        /// - Professional business documents (invoices, reports)
        /// - Contracts or legal documents
        ///
        /// ## CSS Injection
        ///
        /// When set, injects CSS to force dark color scheme:
        /// ```css
        /// :root { color-scheme: dark !important; }
        /// html, body { background-color: #1c1c1e !important; color: white !important; }
        /// ```
        case dark

        /// Respect system appearance (auto)
        ///
        /// PDFs will render with light or dark backgrounds based on the system's
        /// current appearance setting at render time.
        ///
        /// **Use with caution:**
        /// - PDFs generated on a Mac in dark mode will have dark backgrounds
        /// - Same HTML will produce different PDFs depending on system settings
        /// - May surprise users who expect consistent output
        ///
        /// **Best for:**
        /// - User-controlled preferences (let users choose their PDF appearance)
        /// - Applications that intentionally adapt to system theme
        /// - When HTML already handles dark mode correctly with `@media (prefers-color-scheme)`
        ///
        /// ## Behavior
        ///
        /// No CSS is injected - WKWebView respects system `prefers-color-scheme` setting.
        case auto

        /// CSS bytes to inject for this appearance mode
        ///
        /// Returns the CSS bytes that should be injected into the HTML `<head>`
        /// to enforce the appearance, or `nil` for `.auto` mode.
        package var cssInjection: ContiguousArray<UInt8>? {
            switch self {
            case .light:
                let css = """
                <style id="pdf-appearance-light">
                /* Force light appearance for PDF generation */
                :root {
                    color-scheme: light !important;
                }

                @media (prefers-color-scheme: dark) {
                    html, body {
                        background-color: white !important;
                        color: black !important;
                    }
                }

                @media print {
                    html, body {
                        background-color: white !important;
                        color: black !important;
                    }
                }
                </style>
                """
                return ContiguousArray(css.utf8)

            case .dark:
                let css = """
                <style id="pdf-appearance-dark">
                /* Force dark appearance for PDF generation */
                :root {
                    color-scheme: dark !important;
                }

                @media (prefers-color-scheme: light) {
                    html, body {
                        background-color: #1c1c1e !important;
                        color: white !important;
                    }
                }

                @media print {
                    html, body {
                        background-color: #1c1c1e !important;
                        color: white !important;
                    }
                }
                </style>
                """
                return ContiguousArray(css.utf8)

            case .auto:
                // No injection - respect system appearance
                return nil
            }
        }
    }
}
