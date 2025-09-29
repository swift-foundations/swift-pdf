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
        }
    }
}

// MARK: - Convenience Initializers

extension PrintingError {

    /// Create an error from a WebViewPoolActor.Error
    static func from(poolError: WebViewPoolActor.Error) -> PrintingError {
        switch poolError {
        case .timeout:
            return .webViewAcquisitionTimeout(timeoutSeconds: 300) // Default timeout
        case .poolExhausted:
            return .webViewPoolExhausted(pendingRequests: 0)
        case .queueOverload:
            return .webViewPoolExhausted(pendingRequests: 100) // Estimate
        case .cancelled:
            return .cancelled(message: nil)
        }
    }
}