//
//  PDF.Render+TestDependencyKey.swift
//  swift-html-to-pdf
//
//  Test dependency configuration for PDF.Render
//

import Dependencies

extension PDF.Render: TestDependencyKey {
    /// Test value that uses live client and configuration with isolated metrics
    ///
    /// Each test gets:
    /// - Real rendering client (.macOS/.iOS depending on platform) for integration testing
    /// - Real configuration (.default) for accurate behavior
    /// - Isolated metrics (.testValue) that bootstrap fresh backend per test
    ///
    /// This provides realistic testing while ensuring perfect metrics isolation.
    public static var testValue: Self {
        PDF.Render(
            client: liveClient,
            configuration: .default,
            metrics: .testValue
        )
    }

    private static var liveClient: PDF.Render.Client {
        #if os(macOS)
        return .macOS
        #elseif os(iOS)
        return .iOS
        #else
        return .testValue
        #endif
    }
}

extension PDF.Render.Client: TestDependencyKey {
    public static let testValue = PDF.Render.Client()
}
