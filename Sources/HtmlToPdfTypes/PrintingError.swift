//
//  PrintingError.swift
//  swift-html-to-pdf
//
//  Created on 2025-09-29.
//

import Foundation

/// Errors that can occur during PDF printing operations
public enum PrintingError: Error, LocalizedError, Sendable {

    // MARK: - Document Errors

    /// The provided HTML content could not be rendered
    case invalidHTML(String)

    /// The target file path is not accessible or writable
    case invalidFilePath(URL, underlyingError: Error?)

    /// Failed to create required directories
    case directoryCreationFailed(URL, underlyingError: Error)

    // MARK: - WebView Errors

    /// Failed to load HTML content into WebView
    case webViewLoadingFailed(underlyingError: Error)

    /// WebView navigation failed
    case webViewNavigationFailed(underlyingError: Error)

    /// WebView rendering timed out
    case webViewRenderingTimeout(timeoutSeconds: TimeInterval)

    // MARK: - Pool Errors

    /// WebView pool exhausted and cannot provide a WebView
    case webViewPoolExhausted(pendingRequests: Int)

    /// Failed to acquire WebView from pool within timeout
    case webViewAcquisitionTimeout(timeoutSeconds: TimeInterval)

    /// WebView pool initialization failed
    case webViewPoolInitializationFailed(underlyingError: Error?)

    // MARK: - PDF Generation Errors

    /// PDF generation failed
    case pdfGenerationFailed(underlyingError: Error)

    /// Print operation failed
    case printOperationFailed(success: Bool, underlyingError: Error?)

    /// Document processing timed out
    case documentTimeout(documentURL: URL, timeoutSeconds: TimeInterval)

    /// Batch processing timed out
    case batchTimeout(completedCount: Int, totalCount: Int, timeoutSeconds: TimeInterval)

    // MARK: - Cancellation

    /// Operation was cancelled
    case cancelled(message: String?)

    /// No result was produced from rendering operation
    case noResultProduced

    // MARK: - Platform Capability Errors

    /// Platform lacks required capability for this operation
    case capabilityUnavailable(capability: String, platform: String, reason: String)

    // MARK: - LocalizedError Implementation

    public var errorDescription: String? {
        switch self {
        case .invalidHTML(let html):
            let preview = String(html.prefix(100))
            return "Invalid HTML content: \(preview)..."

        case .invalidFilePath(let url, let error):
            if let error = error {
                return "Cannot write to file path '\(url.path)': \(error.localizedDescription)"
            }
            return "Cannot write to file path: \(url.path)"

        case .directoryCreationFailed(let url, let error):
            return "Failed to create directory at '\(url.path)': \(error.localizedDescription)"

        case .webViewLoadingFailed(let error):
            return "Failed to load HTML into WebView: \(error.localizedDescription)"

        case .webViewNavigationFailed(let error):
            return "WebView navigation failed: \(error.localizedDescription)"

        case .webViewRenderingTimeout(let timeout):
            return "WebView rendering timed out after \(Int(timeout)) seconds"

        case .webViewPoolExhausted(let pending):
            return "WebView pool is exhausted with \(pending) pending requests"

        case .webViewAcquisitionTimeout(let timeout):
            return "Failed to acquire WebView from pool within \(Int(timeout)) seconds"

        case .webViewPoolInitializationFailed(let error):
            if let error = error {
                return "WebView pool initialization failed: \(error.localizedDescription)"
            }
            return "WebView pool initialization failed"

        case .pdfGenerationFailed(let error):
            return "PDF generation failed: \(error.localizedDescription)"

        case .printOperationFailed(let success, let error):
            if let error = error {
                return "Print operation failed: \(error.localizedDescription)"
            }
            return "Print operation failed (success: \(success))"

        case .documentTimeout(let url, let timeout):
            return "Document processing timed out for '\(url.lastPathComponent)' after \(Int(timeout)) seconds"

        case .batchTimeout(let completed, let total, let timeout):
            return "Batch processing timed out after \(Int(timeout)) seconds (\(completed)/\(total) completed)"

        case .cancelled(let message):
            if let message = message {
                return "Operation cancelled: \(message)"
            }
            return "Operation cancelled"

        case .noResultProduced:
            return "No result was produced from rendering operation"

        case .capabilityUnavailable(let capability, let platform, let reason):
            return "Platform '\(platform)' does not support '\(capability)': \(reason)"
        }
    }

    public var failureReason: String? {
        switch self {
        case .invalidHTML:
            return "The HTML content may be malformed or contain unsupported elements"

        case .invalidFilePath:
            return "The file path may not exist, lack write permissions, or be on a read-only volume"

        case .directoryCreationFailed:
            return "Insufficient permissions or disk space to create the directory"

        case .webViewLoadingFailed, .webViewNavigationFailed:
            return "The HTML content may contain resources that cannot be loaded"

        case .webViewRenderingTimeout:
            return "The HTML content may be too complex or contain infinite loops"

        case .webViewPoolExhausted:
            return "Too many concurrent print operations for available resources"

        case .webViewAcquisitionTimeout:
            return "All WebViews are busy processing other documents"

        case .webViewPoolInitializationFailed:
            return "System resources may be insufficient to create WebViews"

        case .pdfGenerationFailed:
            return "The rendering engine encountered an error creating the PDF"

        case .printOperationFailed:
            return "The system print operation could not complete"

        case .documentTimeout:
            return "Document is too large or complex to process within the timeout"

        case .batchTimeout:
            return "Batch contains too many documents to process within the timeout"

        case .cancelled:
            return "User or system cancelled the operation"

        case .noResultProduced:
            return "The rendering operation completed but produced no output"

        case .capabilityUnavailable:
            return "This operation requires platform capabilities that are not available"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .invalidHTML:
            return "Validate your HTML using an HTML validator and ensure it's well-formed"

        case .invalidFilePath:
            return "Verify the file path exists and has write permissions"

        case .directoryCreationFailed:
            return "Check disk space and permissions for the parent directory"

        case .webViewLoadingFailed, .webViewNavigationFailed:
            return "Ensure all referenced resources are accessible or use base64-encoded data"

        case .webViewRenderingTimeout:
            return "Simplify the HTML content or increase the timeout duration"

        case .webViewPoolExhausted:
            return "Reduce maxConcurrentOperations in PrintingConfiguration"

        case .webViewAcquisitionTimeout:
            return "Increase webViewAcquisitionTimeout or reduce concurrent operations"

        case .webViewPoolInitializationFailed:
            return "Restart the application or reduce the pool size"

        case .pdfGenerationFailed:
            return "Check the HTML content for rendering issues"

        case .printOperationFailed:
            return "Check system print settings and available disk space"

        case .documentTimeout:
            return "Increase documentTimeout in PrintingConfiguration or simplify the document"

        case .batchTimeout:
            return "Increase batchTimeout, reduce batch size, or process in smaller chunks"

        case .cancelled:
            return "Retry the operation if needed"

        case .noResultProduced:
            return "Check that the document was properly configured and retry"

        case .capabilityUnavailable(let capability, let platform, _):
            return "Use a different platform or reduce '\(capability)' requirements to match '\(platform)' capabilities"
        }
    }
}

// MARK: - Error Code Support

extension PrintingError {
    /// Stable error code for programmatic branching
    ///
    /// Use this for switch statements and error handling logic instead of pattern matching.
    /// These codes are guaranteed to remain stable across versions for long-term compatibility.
    ///
    /// Example:
    /// ```swift
    /// do {
    ///     try await pdf.render(html, to: url)
    /// } catch let error as PrintingError {
    ///     switch error.errorCode {
    ///     case "webview_acquisition_timeout":
    ///         // Increase timeout and retry
    ///     case "pdf_generation_failed":
    ///         // Check underlying error
    ///         if let underlying = error.underlyingError {
    ///             // Handle specific underlying error
    ///         }
    ///     default:
    ///         // Generic error handling
    ///     }
    /// }
    /// ```
    public var errorCode: String {
        metricsReason
    }

    /// Access to underlying error for branching logic
    ///
    /// Many errors wrap underlying system errors (WKError, URLError, NSError).
    /// Use this to access the underlying error for more specific error handling.
    public var underlyingError: Error? {
        switch self {
        case .invalidFilePath(_, let error),
             .webViewPoolInitializationFailed(let error),
             .printOperationFailed(_, let error):
            return error
        case .directoryCreationFailed(_, let error),
             .webViewLoadingFailed(let error),
             .webViewNavigationFailed(let error),
             .pdfGenerationFailed(let error):
            return error
        default:
            return nil
        }
    }
}

// MARK: - Metrics Support

extension PrintingError {
    /// Label for metrics dimension tracking
    ///
    /// Provides a stable string representation for use in metrics dimensions.
    /// This allows segmentation of failure metrics by error type.
    var metricsReason: String {
        switch self {
        // Document Errors
        case .invalidHTML:
            return "invalid_html"
        case .invalidFilePath:
            return "invalid_file_path"
        case .directoryCreationFailed:
            return "directory_creation_failed"

        // WebView Errors
        case .webViewLoadingFailed:
            return "webview_loading_failed"
        case .webViewNavigationFailed:
            return "webview_navigation_failed"
        case .webViewRenderingTimeout:
            return "webview_rendering_timeout"

        // Pool Errors
        case .webViewPoolExhausted:
            return "webview_pool_exhausted"
        case .webViewAcquisitionTimeout:
            return "webview_acquisition_timeout"
        case .webViewPoolInitializationFailed:
            return "webview_pool_initialization_failed"

        // PDF Generation Errors
        case .pdfGenerationFailed:
            return "pdf_generation_failed"
        case .printOperationFailed:
            return "print_operation_failed"
        case .documentTimeout:
            return "document_timeout"
        case .batchTimeout:
            return "batch_timeout"

        // Cancellation
        case .cancelled:
            return "cancelled"
        case .noResultProduced:
            return "no_result_produced"

        // Platform Capability Errors
        case .capabilityUnavailable:
            return "capability_unavailable"
        }
    }
}
