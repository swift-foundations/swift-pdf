//
//  TestImages.swift
//  PDFTestSupport
//
//  Image loading utilities for PDF testing
//

import Foundation

/// Test image utilities for loading and encoding test images
public enum TestImages {
    /// Load an image from the test bundle and encode as base64
    ///
    /// Usage:
    /// ```swift
    /// // In test file with Bundle.module:
    /// let base64PNG = try TestImages.loadBase64(named: "coenttb", extension: "png", from: .module)
    /// let html = #"<img src="data:image/png;base64,\#(base64PNG)">"#
    /// ```
    ///
    /// - Parameters:
    ///   - name: Image filename without extension
    ///   - ext: File extension (e.g., "png", "jpg")
    ///   - bundle: Bundle containing the resource (must be provided by caller)
    /// - Returns: Base64-encoded string of the image data
    /// - Throws: Error if image resource not found
    public static func loadBase64(
        named name: String,
        extension ext: String,
        from bundle: Bundle
    ) throws -> String {
        guard let imageURL = bundle.url(forResource: name, withExtension: ext) else {
            throw TestError.resourceNotFound(name: "\(name).\(ext)")
        }
        let imageData = try Data(contentsOf: imageURL)
        return imageData.base64EncodedString()
    }

    /// Common SVG test images encoded as base64
    public enum SVG {
        /// Red 50x50px square
        public static let redSquare = "PHN2ZyB3aWR0aD0iNTAiIGhlaWdodD0iNTAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+PHJlY3Qgd2lkdGg9IjUwIiBoZWlnaHQ9IjUwIiBmaWxsPSIjZmYwMDAwIi8+PC9zdmc+"

        /// Green 50x50px square
        public static let greenSquare = "PHN2ZyB3aWR0aD0iNTAiIGhlaWdodD0iNTAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+PHJlY3Qgd2lkdGg9IjUwIiBoZWlnaHQ9IjUwIiBmaWxsPSIjMDBmZjAwIi8+PC9zdmc+"

        /// Blue 50x50px square
        public static let blueSquare = "PHN2ZyB3aWR0aD0iNTAiIGhlaWdodD0iNTAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+PHJlY3Qgd2lkdGg9IjUwIiBoZWlnaHQ9IjUwIiBmaWxsPSIjMDAwMGZmIi8+PC9zdmc+"
    }

    public enum TestError: Error, CustomStringConvertible {
        case resourceNotFound(name: String)

        public var description: String {
            switch self {
            case .resourceNotFound(let name):
                return "Test resource not found: \(name)"
            }
        }
    }
}
