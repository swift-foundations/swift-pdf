//
//  PDF.EdgeInsets.swift
//  swift-html-to-pdf
//
//  Edge insets for PDF margins
//

import Foundation

/// Edge insets for defining margins
public struct EdgeInsets: Sendable {
    public let top: CGFloat
    public let left: CGFloat
    public let bottom: CGFloat
    public let right: CGFloat

    public init(top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }

    // Convenience initializers
    public init(all: CGFloat) {
        self.init(top: all, left: all, bottom: all, right: all)
    }

    public init(horizontal: CGFloat, vertical: CGFloat) {
        self.init(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }
}

// MARK: - Presets

extension EdgeInsets {
    /// No margins
    public static let none = EdgeInsets(all: 0)

    /// Minimal margins (0.25 inch)
    public static let minimal = EdgeInsets(all: 18)

    /// Standard margins (0.5 inch)
    public static let standard = EdgeInsets(all: 36)

    /// Comfortable margins (0.75 inch)
    public static let comfortable = EdgeInsets(all: 54)

    /// Wide margins (1 inch)
    public static let wide = EdgeInsets(all: 72)
}

// MARK: - Platform Conversions

#if os(macOS)
import AppKit

extension NSEdgeInsets {
    init(edgeInsets: EdgeInsets) {
        self = .init(
            top: edgeInsets.top,
            left: edgeInsets.left,
            bottom: edgeInsets.bottom,
            right: edgeInsets.right
        )
    }
}
#endif

#if canImport(UIKit)
import UIKit

extension UIEdgeInsets {
    init(edgeInsets: EdgeInsets) {
        self = .init(
            top: .init(edgeInsets.top),
            left: .init(edgeInsets.left),
            bottom: .init(edgeInsets.bottom),
            right: .init(edgeInsets.right)
        )
    }
}
#endif
