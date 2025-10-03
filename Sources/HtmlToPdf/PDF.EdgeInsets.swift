//
//  PDF.EdgeInsets.swift
//  swift-html-to-pdf
//
//  Edge insets for PDF margins
//

import Foundation

/// Edge insets for defining margins
///
/// All margin values must be non-negative. Negative values are automatically clamped to zero.
///
/// ## Example
///
/// ```swift
/// // Using presets (recommended)
/// let margins = EdgeInsets.standard  // 0.5 inch (36pt) on all sides
///
/// // Custom margins
/// let margins = EdgeInsets(top: 50, left: 40, bottom: 50, right: 40)
///
/// // Negative values are clamped to zero
/// let margins = EdgeInsets(all: -10)  // Results in 0 on all sides
/// ```
public struct EdgeInsets: Sendable {
    public let top: CGFloat
    public let left: CGFloat
    public let bottom: CGFloat
    public let right: CGFloat

    /// Creates edge insets with the specified margins
    ///
    /// Negative values are automatically clamped to zero to prevent invalid margin configurations.
    ///
    /// - Parameters:
    ///   - top: Top margin in points (clamped to >= 0)
    ///   - left: Left margin in points (clamped to >= 0)
    ///   - bottom: Bottom margin in points (clamped to >= 0)
    ///   - right: Right margin in points (clamped to >= 0)
    public init(top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) {
        self.top = max(0, top)
        self.left = max(0, left)
        self.bottom = max(0, bottom)
        self.right = max(0, right)
    }

    // Convenience initializers

    /// Creates edge insets with the same margin on all sides
    ///
    /// Negative values are automatically clamped to zero.
    ///
    /// - Parameter all: Margin for all sides in points (clamped to >= 0)
    public init(all: CGFloat) {
        self.init(top: all, left: all, bottom: all, right: all)
    }

    /// Creates edge insets with horizontal and vertical margins
    ///
    /// Negative values are automatically clamped to zero.
    ///
    /// - Parameters:
    ///   - horizontal: Left and right margin in points (clamped to >= 0)
    ///   - vertical: Top and bottom margin in points (clamped to >= 0)
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
