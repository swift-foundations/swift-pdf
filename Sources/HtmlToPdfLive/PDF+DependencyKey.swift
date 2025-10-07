//
//  PDF+DependencyKey.swift
//  swift-html-to-pdf
//
//  DependencyKey conformances for live implementations
//

import Dependencies
import HtmlToPdfTypes

extension PDF: DependencyKey {
    public static let liveValue = PDF(
        render: .liveValue
    )
}

extension DependencyValues {
    public var pdf: PDF {
        get { self[PDF.self] }
        set { self[PDF.self] = newValue }
    }
}
