//
//  PDF.Render+TestDependencyKey.swift
//  swift-html-to-pdf
//
//  Test dependency configuration for PDF.Render
//

import Dependencies

extension PDF.Render: TestDependencyKey {
    public static let testValue = PDF.Render(
        client: .testValue,
        configuration: .testValue
    )
}

extension PDF.Render.Client: TestDependencyKey {
    public static let testValue = PDF.Render.Client()
}
