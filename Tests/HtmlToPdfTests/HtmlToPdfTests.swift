//
//  HtmlToPdfTests.swift
//
//
//  Created by Coen ten Thije Boonkkamp on 15/07/2024.
//

import Foundation
@testable import HtmlToPdf
import Testing

@Suite("Temporary")
struct TemporaryDirectory {

    @Test func collection() async throws {
        let count = 1000

        let output = URL.output()
        defer { 
            do {
                try FileManager.default.removeItem(at: output) 
            } catch {
                // Silently ignore removal errors in cleanup
                print("Warning: Could not remove output directory: \(error.localizedDescription)")
            }
        }
        try await [String].init(
            repeating: "<html><body><h1>Hello, World 1!</h1></body></html>",
            count: count
        )
        .print(to: output)

        #expect(try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil).count == count)
    }

    @Test() func individual() async throws {
        let id = UUID()
        let output = URL.output(id: id).appendingPathComponent("individual")
        defer { 
            do {
                try FileManager.default.removeItem(at: output) 
            } catch {
                print("Warning: Could not remove output directory: \(error.localizedDescription)")
            }
        }

        try await String.html.print(to: output.appendingPathComponent("\(id.uuidString) test string").appendingPathExtension("pdf"), configuration: .a4)

        #expect(try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil).count == 1)
    }

    @Test func collection_n_size() async throws {
        let count = 10
        let output = URL.output()
        defer { 
            do {
                try FileManager.default.removeItem(at: output) 
            } catch {
                print("Warning: Could not remove output directory: \(error.localizedDescription)")
            }
        }

        try await [String].init(repeating: .html, count: count)
            .print(to: output, configuration: .a4)

        #expect(try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil).count == count)
    }

    @Test func collection_n_size_concurrently() async throws {
        let count = 10
        let output = URL.output()
        defer { 
            do {
                try FileManager.default.removeItem(at: output) 
            } catch {
                print("Warning: Could not remove output directory: \(error.localizedDescription)")
            }
        }

        try await [String].init(repeating: .html, count: count)
            .print(
                to: output,
                configuration: .a4,
                filename: { _ in UUID().uuidString }
            )

        try await [String].init(repeating: .html, count: count)
            .print(
                to: output, configuration: .a4,
                filename: { _ in UUID().uuidString }
            )

        #expect(try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil).count == (count * 2) )
    }

    @Test func collection_of_documents() async throws {
        let output = URL.output()
        defer {
            do {
                try FileManager.default.removeItem(at: output)
            } catch {
                // Silently ignore removal errors in cleanup
                print("Warning: Could not remove output directory: \(error.localizedDescription)")
            }
        }

        let documents = [
            Document(
                fileUrl: output.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf"),
                html: .html
            ),
            Document(
                fileUrl: output.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf"),
                html: .html
            ),
            Document(
                fileUrl: output.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf"),
                html: .html
            ),
            Document(
                fileUrl: output.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf"),
                html: .html
            ),
            Document(
                fileUrl: output.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf"),
                html: .html
            ),
            Document(
                fileUrl: output.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf"),
                html: .html
            )
        ]

        try await documents.print(
            configuration: .a4
        )

        #expect(try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil).count == documents.count)
    }

    @Test func collection_collection_individual() async throws {
        let count = 10
        let output = URL.output()
        defer {
            do {
                try FileManager.default.removeItem(at: output)
            } catch {
                // Silently ignore removal errors in cleanup
                print("Warning: Could not remove output directory: \(error.localizedDescription)")
            }
        }

        try await [String].init(repeating: .html, count: count)
            .print(
                to: output,
                configuration: .a4,
                filename: { _ in UUID().uuidString }
            )

        try await [String].init(repeating: .html, count: count)
            .print(
                to: output, configuration: .a4,
                filename: { _ in UUID().uuidString }
            )

        try await String.html.print(
            title: UUID().uuidString,
            to: output,
            configuration: .a4
        )

        #expect(try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil).count == (count * 2) + 1 )
    }

    @Test func collection_3() async throws {
        let output = URL.output()
        defer {
            do {
                try FileManager.default.removeItem(at: output)
            } catch {
                // Silently ignore removal errors in cleanup
                print("Warning: Could not remove output directory: \(error.localizedDescription)")
            }
        }

        let documents = [
            Document(
                fileUrl: output.appendingPathComponent("file1").appendingPathExtension("pdf"),
                html: .html
            ),
            Document(
                fileUrl: output.appendingPathComponent("file2").appendingPathExtension("pdf"),
                html: .html
            ),
            Document(
                fileUrl: output.appendingPathComponent("file3").appendingPathExtension("pdf"),
                html: .html
            ),
            Document(
                fileUrl: output.appendingPathComponent("file4").appendingPathExtension("pdf"),
                html: .html
            ),
            Document(
                fileUrl: output.appendingPathComponent("file5").appendingPathExtension("pdf"),
                html: .html
            ),
            Document(
                fileUrl: output.appendingPathComponent("file6").appendingPathExtension("pdf"),
                html: .html
            )
        ]

        try await documents.print(
            configuration: .a4
        )

        let count = 10

        try await [String].init(repeating: "<html><body><h1>Hello, World 2!</h1></body></html>", count: count)
            .print(
                to: output,
                filename: { _ in UUID().uuidString }
            )

        try await "<html><body><h1>Hello, World!</h1></body></html>".print(
            title: UUID().uuidString,
            to: output,
            configuration: .a4
        )

        #expect(try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil).count == documents.count + count + 1)
    }
    
    @Test("Collection IMG Test")
    func testCollection() async throws {
        let count = 10

        let output = URL.output()
        
        defer {
            do {
                try FileManager.default.removeItem(at: output)
            } catch {
                // Silently ignore removal errors in cleanup
                print("Warning: Could not remove output directory: \(error.localizedDescription)")
            }
        }
        
        try await [String](
            repeating: "<html><body><h1>Hello, World 1!</h1>\(String.img)</body></html>",
            count: count
        )
            .print(to: output)

        let resultCount = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil).count
        #expect(resultCount == count)
    }
}

#if os(macOS) || targetEnvironment(macCatalyst)
@Suite("Local")
struct Local {
    @Test() func individual() async throws {
        let title = "individual"
        let output = URL.localHtmlToPdf
        let expectedFile = output.appendingPathComponent(title).appendingPathExtension("pdf")

         defer {
             do {
                 try FileManager.default.removeItem(at: expectedFile)
             } catch {
                 // Silently ignore removal errors in cleanup
                 print("Warning: Could not remove file: \(error.localizedDescription)")
             }
         }

        try await String.html.print(title: title, to: output, configuration: .a4)

        #expect(FileManager.default.fileExists(atPath: expectedFile.path))
    }

    @Test() func collection_of_strings() async throws {
        let title = "collection_of_strings"
        let output = URL.localHtmlToPdf.appendingPathComponent(title)
        
        defer {
            do {
                try FileManager.default.removeItem(at: output)
            } catch {
                // Silently ignore removal errors in cleanup
                print("Warning: Could not remove output directory: \(error.localizedDescription)")
            }
        }
        
        let count = 3

        try await [String].init(repeating: .html, count: count)
            .print(to: output)

        #expect(try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil).count == count)
    }

    @Test() func collection_of_documents() async throws {
        let title = "collection_of_documents"
        let output = URL.localHtmlToPdf.appendingPathComponent(title)
        
        defer {
            do {
                try FileManager.default.removeItem(at: output)
            } catch {
                // Silently ignore removal errors in cleanup
                print("Warning: Could not remove output directory: \(error.localizedDescription)")
            }
        }
        
        let count = 3

        try await (1...count).map { count in
            Document(fileUrl: output.appendingPathComponent("\(count)").appendingPathExtension("pdf"), html: .html)
        }.print(configuration: .a4)

        #expect(try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil).count == count)

    }
}
#endif

@Suite("AsyncStream")
struct AsyncStreamTests {
    @Test func collection_n_size() async throws {

        let count = 1
        let output = URL.output()
        
        defer {
            do {
                try FileManager.default.removeItem(at: output)
            } catch {
                // Silently ignore removal errors in cleanup
                print("Warning: Could not remove output directory: \(error.localizedDescription)")
            }
        }

        let urls: AsyncThrowingStream<URL, Error> = try await [String].init(repeating: .html, count: count)
            .print(
                to: output,
                configuration: .a4,
                filename: { _ in UUID().uuidString }
            )

        try await urls.testIfYieldedUrlExistsOnFileSystem(directory: output)

        #expect(try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil).count == count)

    }

    @Test(
        "collection_n_size_concurrently",
        arguments: [
            URL.localHtmlToPdf.appendingPathComponent("local_collection_n_size_concurrently"),
            URL.output()
        ]
    ) func local_collection_n_size_concurrently(url: URL) async throws {
        let count = 50
        let output = url
        
        defer {
            do {
                try FileManager.default.removeItem(at: output)
            } catch {
                // Silently ignore removal errors in cleanup
                print("Warning: Could not remove output directory: \(error.localizedDescription)")
            }
        }

        async let x: AsyncThrowingStream<URL, Error> = try [String].init(repeating: .html, count: count)
            .print(
                to: output,
                configuration: .a4,
                filename: { _ in UUID().uuidString }
            )

        async let y: AsyncThrowingStream<URL, Error> = try [String].init(repeating: .html, count: count)
            .print(
                to: output, configuration: .a4,
                filename: { _ in UUID().uuidString }
            )

        try await x.testIfYieldedUrlExistsOnFileSystem(directory: output)

        try await y.testIfYieldedUrlExistsOnFileSystem(directory: output)

        #expect(try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil).count == (count * 2) )

    }

    @Test() func collection_of_documents() async throws {

        let output = URL.output()
        
        defer {
            do {
                try FileManager.default.removeItem(at: output)
            } catch {
                // Silently ignore removal errors in cleanup
                print("Warning: Could not remove output directory: \(error.localizedDescription)")
            }
        }
        
        let count = 3

        let urls: AsyncThrowingStream<URL, Error> = try await (1...count).map { count in
            Document(fileUrl: output.appendingPathComponent("\(count)").appendingPathExtension("pdf"), html: .html)
        }.print(configuration: .a4)

        try await urls.testIfYieldedUrlExistsOnFileSystem(directory: output)

        #expect(try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil).count == count)
    }
}


extension String {
    static let img = #"<img src="data:image/png;charset=utf-8;base64, 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" alt="HUOC Logo">"#
}


