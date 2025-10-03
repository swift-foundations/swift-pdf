//
//  PDF.PaperSize.swift
//  swift-html-to-pdf
//
//  Paper size extensions for CGSize
//

import Foundation

/// Paper size extensions for CGSize
///
/// Provides standard paper sizes in points (1 point = 1/72 inch).
///
/// ## Important
///
/// When creating custom paper sizes, ensure both width and height are positive values.
/// Using the provided static properties (`.a4`, `.letter`, etc.) is recommended for
/// standard sizes.
///
/// ## Example
///
/// ```swift
/// // Using standard sizes (recommended)
/// configuration.paperSize = .a4
/// configuration.paperSize = .letter
///
/// // Custom size
/// configuration.paperSize = CGSize(width: 600, height: 800)
///
/// // Landscape orientation
/// configuration.paperSize = .a4.landscape
/// ```
extension CGSize {
    // MARK: - ISO 216 Sizes (in points)

    /// A3 paper size (297 × 420 mm)
    public static let a3 = CGSize(width: 841.89, height: 1190.55)

    /// A4 paper size (210 × 297 mm)
    public static let a4 = CGSize(width: 595.28, height: 841.89)

    /// A5 paper size (148 × 210 mm)
    public static let a5 = CGSize(width: 420.94, height: 595.28)

    // MARK: - US Paper Sizes (in points)

    /// US Letter size (8.5 × 11 inches)
    public static let letter = CGSize(width: 612, height: 792)

    /// US Legal size (8.5 × 14 inches)
    public static let legal = CGSize(width: 612, height: 1008)

    /// US Tabloid size (11 × 17 inches)
    public static let tabloid = CGSize(width: 792, height: 1224)

    // MARK: - Orientation

    /// Returns landscape version of this size (wider than tall)
    public var landscape: CGSize {
        CGSize(
            width: max(width, height),
            height: min(width, height)
        )
    }

    /// Returns portrait version of this size (taller than wide)
    public var portrait: CGSize {
        CGSize(
            width: min(width, height),
            height: max(width, height)
        )
    }

    /// Whether this size is landscape orientation
    public var isLandscape: Bool { width > height }

    /// Whether this size is portrait orientation
    public var isPortrait: Bool { height >= width }
}
