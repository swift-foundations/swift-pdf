//
//  PDF.Render.Result.swift
//  swift-html-to-pdf
//
//  Result type for batch rendering operations
//

import Foundation

extension PDF.Render {
    /// Result of a batch rendering operation
    ///
    /// Used in resilient batch processing to distinguish between successful and failed documents.
    public enum BatchResult: Sendable {
        /// Document rendered successfully
        case success(PDF.Result)

        /// Document failed to render
        case failure(PDF.FailedDocument)
    }
}
