//
//  AppearanceTests.swift
//  swift-html-to-pdf
//
//  Tests for PDF.Appearance (light/dark/auto mode)
//

import Testing
import Foundation
import Dependencies
@testable import HtmlToPdfLive

@Suite("PDF Appearance Tests")
struct AppearanceTests {

    @Test("Light appearance is the default")
    func lightIsDefault() async throws {
        let config = PDF.Configuration()
        #expect(config.appearance == .light)
    }

    @Test("Light appearance generates white background CSS")
    func lightAppearanceCSS() async throws {
        let appearance = PDF.Appearance.light
        let cssBytes = appearance.cssInjection

        #expect(cssBytes != nil)

        if let css = cssBytes {
            let cssString = String(decoding: css, as: UTF8.self)
            #expect(cssString.contains("background-color: white"))
            #expect(cssString.contains("color: black"))
            #expect(cssString.contains("color-scheme: light"))
        }
    }

    @Test("Dark appearance generates dark background CSS")
    func darkAppearanceCSS() async throws {
        let appearance = PDF.Appearance.dark
        let cssBytes = appearance.cssInjection

        #expect(cssBytes != nil)

        if let css = cssBytes {
            let cssString = String(decoding: css, as: UTF8.self)
            #expect(cssString.contains("background-color: #1c1c1e"))
            #expect(cssString.contains("color: white"))
            #expect(cssString.contains("color-scheme: dark"))
        }
    }

    @Test("Auto appearance generates no CSS")
    func autoAppearanceNoCSS() async throws {
        let appearance = PDF.Appearance.auto
        let cssBytes = appearance.cssInjection

        #expect(cssBytes == nil)
    }

    @Test("PDF renders with light appearance by default")
    func renderWithDefaultLight() async throws {
        @Dependency(\.pdf) var pdf

        let html = "<html><body><h1>Test Light Appearance</h1></body></html>"
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("light-test-\(UUID()).pdf")

        // Should use light appearance by default
        _ = try await pdf.render(html: html, to: tempFile)

        #expect(FileManager.default.fileExists(atPath: tempFile.path))

        // Cleanup
        try? FileManager.default.removeItem(at: tempFile)
    }

    @Test("PDF renders with dark appearance when configured")
    func renderWithDarkAppearance() async throws {
        @Dependency(\.pdf) var pdf

        let html = "<html><body><h1>Test Dark Appearance</h1></body></html>"
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("dark-test-\(UUID()).pdf")

        try await withDependencies {
            $0.pdf.render.configuration.appearance = .dark
        } operation: {
            try await pdf.render(html: html, to: tempFile)
        }

        #expect(FileManager.default.fileExists(atPath: tempFile.path))

        // Cleanup
        try? FileManager.default.removeItem(at: tempFile)
    }

    @Test("PDF renders with auto appearance when configured")
    func renderWithAutoAppearance() async throws {
        @Dependency(\.pdf) var pdf

        let html = "<html><body><h1>Test Auto Appearance</h1></body></html>"
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("auto-test-\(UUID()).pdf")

        try await withDependencies {
            $0.pdf.render.configuration.appearance = .auto
        } operation: {
            try await pdf.render(html: html, to: tempFile)
        }

        #expect(FileManager.default.fileExists(atPath: tempFile.path))

        // Cleanup
        try? FileManager.default.removeItem(at: tempFile)
    }
}
