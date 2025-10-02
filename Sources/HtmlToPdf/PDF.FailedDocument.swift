//
//  PDF.FailedDocument.swift
//  swift-html-to-pdf
//
//  Error information for failed document rendering
//

import Foundation

extension PDF {
    /// Information about a document that failed to render
    ///
    /// Used in resilient batch operations to report failures without stopping the entire batch.
    public struct FailedDocument: Sendable, Error {
        /// The document that failed to render
        public let document: PDF.Document

        /// The index of this document in the batch
        public let index: Int

        /// The underlying error that caused the failure
        public let error: Error

        /// How long was spent attempting to render before failure
        public let duration: Duration

        public init(
            document: PDF.Document,
            index: Int,
            error: Error,
            duration: Duration
        ) {
            self.document = document
            self.index = index
            self.error = error
            self.duration = duration
        }
    }
}

extension PDF.FailedDocument: LocalizedError {
    public var errorDescription: String? {
        "Failed to render document \(index + 1) ('\(document.destination.lastPathComponent)'): \(error.localizedDescription)"
    }

    public var failureReason: String? {
        (error as? LocalizedError)?.failureReason
    }

    public var recoverySuggestion: String? {
        (error as? LocalizedError)?.recoverySuggestion
    }
}
