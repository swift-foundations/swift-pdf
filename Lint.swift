// swift-linter-tools-version: 0.1
// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-pdf open source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the swift-pdf project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Linter
import Linter_Institute_Rules

Lint.run(dependencies: [
    .package(
        url: "https://github.com/swift-foundations/swift-institute-linter-rules.git",
        branch: "main",
        products: ["Linter Institute Rules"]
    ),
]) {
    Lint.Rule.Bundle.institute
}
