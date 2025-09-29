//
//  File.swift
//
//
//  Created by Coen ten Thije Boonkkamp on 18/07/2024.
//

import Foundation

extension Sequence<Document> where Self: Sendable {
    /// Prints a sequence of ``Document``  to PDFs at the given directory.
    ///
    /// ## Example
    /// ```swift
    /// let documents = [
    ///     Document(...),
    ///     Document(...),
    ///     Document(...),
    ///     ...
    /// ]
    /// try await documents.print(to: .downloadsDirectory)
    /// ```
    ///
    /// - Parameters:
    ///   - configuration: The configuration that the pdfs will use.
    ///   - createDirectories: If true, the function will call FileManager.default.createDirectory for each document's directory.
    ///
    /// - Returns: An ``AsyncStream<URL>`` that yields the URL once a Document is printed to a PDF.
    ///
    @_disfavoredOverload
    public func print(
        configuration: PDFConfiguration,
        createDirectories: Bool = true
    ) async throws -> AsyncThrowingStream<URL, Error> {
        AsyncThrowingStream<URL, Error> { continuation in
            Task { [documents = self] in
                do {
                    try await withThrowingTaskGroup(of: URL.self) { taskGroup in
                        // First add all tasks to the group
                        for document in documents {
                            taskGroup.addTask {
                                try await document.print(
                                    configuration: configuration,
                                    createDirectories: createDirectories
                                )
                                return document.fileUrl
                            }
                        }

                        // Yield results as they complete
                        for try await url in taskGroup {
                            continuation.yield(url)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

extension Sequence<String> {
    /// Prints a collection of String to PDFs at the given directory and returns .
    ///
    /// ## Example
    /// ```swift
    /// let htmls = [
    ///     "<html><body><h1>Hello, World 1!</h1></body></html>",
    ///     "<html><body><h1>Hello, World 1!</h1></body></html>",
    ///     ...
    /// ]
    /// try await htmls.print(to: .downloadsDirectory)
    /// ```
    ///
    /// - Parameters:
    ///   - directory: The directory at which to print the documents.
    ///   - configuration: The configuration that the PDFs will use.
    ///   - fileName: A closure that, given an Int that represents the index of the String in the collection, returns a fileName. Defaults to just the Index + 1.
    ///   - createDirectories: If true, the function will call FileManager.default.createDirectory for each document's directory.
    ///
    /// - Returns: An ``AsyncStream<URL>`` that yields the URL once a Document is printed to a PDF.
    ///
    @_disfavoredOverload
    public func print(
        to directory: URL,
        configuration: PDFConfiguration = .a4,
        filename: (Int) -> String = { index in "\(index + 1)" },
        createDirectories: Bool = true
    ) async throws -> AsyncThrowingStream<URL, Error> {
        let documents: [Document] = self.enumerated()
            .map { (index, html) in
                Document(
                    fileUrl: directory
                        .appendingPathComponent(filename(index))
                        .appendingPathExtension("pdf"),
                    html: html
                )
            }
        return try await documents.print(
            configuration: configuration,
            createDirectories: createDirectories
        )
    }
}
