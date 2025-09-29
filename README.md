# HtmlToPdf

[![CI](https://github.com/coenttb/swift-html-to-pdf/actions/workflows/ci.yml/badge.svg)](https://github.com/coenttb/swift-html-to-pdf/actions/workflows/ci.yml)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%20%7C%20iOS-blue.svg)](https://github.com/coenttb/swift-html-to-pdf)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)

HtmlToPdf provides an easy-to-use interface for concurrently printing HTML to PDF on iOS and macOS.

## Features

- Convert HTML strings to PDF documents on both iOS and macOS.
- Lightweight and fast: it can handle thousands of documents quickly.
- Customize margins for PDF documents.
- Swift 6 language mode enabled
- And one more thing: easily print images in your PDFs!

## Examples

Print to a file url:
```swift
try await "<html><body><h1>Hello, World 1!</h1></body></html>".print(to: URL(...))
```
Print to a directory with a file title.
```swift
let directory = URL(...)
let html = "<html><body><h1>Hello, World 1!</h1></body></html>"
try await html.print(title: "file title", to: directory)
```

Print a collection to a directory.
```swift
let directory = URL(...)
try await [
    html,
    html,
    html,
    ....
]
.print(to: directory)
```

## Configuration Options

### PrintingConfiguration

Control printing behavior and resource management with `PrintingConfiguration`:

```swift
// Default configuration - suitable for most use cases
try await htmls.print(
    to: directory,
    printingConfiguration: .default
)

// Large batch configuration - optimized for millions of documents
try await htmls.print(
    to: directory,
    printingConfiguration: .largeBatch
)

// Custom configuration with progress tracking
let config = PrintingConfiguration(
    maxConcurrentOperations: 8,           // Limit concurrent prints
    documentTimeout: 30,                  // Timeout per document (seconds)
    batchTimeout: 3600,                   // Overall batch timeout (seconds)
    webViewAcquisitionTimeout: 60,        // WebView acquisition timeout
    progressHandler: { completed, total in
        print("Progress: \(completed)/\(total)")
    }
)
try await htmls.print(
    to: directory,
    printingConfiguration: config
)
```

## Performance

The package includes a test that prints 1000 HTML strings to PDFs in ~2.6 seconds (using ``UIPrintPageRenderer`` on iOS or Mac Catalyst) or ~12 seconds (using ``NSPrintOperation`` on MacOS).

```swift
@Test func collection() async throws {
    [...]
    let count = 1_000
    try await [String].init(
        repeating: "<html><body><h1>Hello, World 1!</h1></body></html>",
        count: count
    )
    .print(to: URL(...))
    [...]
}
```

### ``AsyncStream<URL>``

Optionally, you can invoke an overload that returns an ``AsyncStream<URL>`` that yields the URL of each printed PDF.
> [!NOTE] 
> You need to include the ``AsyncStream`` type signature in the variable declaration, otherwise the return value will be Void.

```swift
let directory = URL(...)
let urls: AsyncStream = try await [
    html,
    html,
    html,
    ....
]
.print(to: directory)

for await url in urls {
    Swift.print(url)
}
```

## Including Images in PDFs

HtmlToPdf supports base64-encoded images out of the box.

> [!Important]
> You are responsible for encoding your images to base64.

### Example HTML
The example below will correctly render the image in the HTML, assuming the `[...]` is replaced with a valid base64-encoded string.

```swift
"<html><body><h1>Hello, World 1!</h1><img src="data:image/png;charset=utf-8;base64, [...]" alt="imageDescription"></body></html>"
   .print(to: URL(...))
```

> [!Tip]
> You can use swift to load the image from a relative or absolute path and then convert them to base64.
> Here's how you can achieve this using the convenience initializer on Image using [coenttb/swift-html](https://www.github.com/coenttb/swift-html):
> ```
> struct Example: HTML {
>     var body: some HTML {
>         [...]
>         if let image = Image(base64EncodedFromURL: "path/to/your/image.jpg", description: "Description of the image") {
>             image
>         }
>         [...]
>     }
> } 
> ```
> [Click here for the implementation of `Image.init(base64EncodedFromURL:)`](https://github.com/coenttb/swift-html/blob/main/Sources/HTML/Image.swift), which shows how to encode an image to base64.

## Related projects

### The coenttb stack

* [swift-css](https://www.github.com/coenttb/swift-css): A Swift DSL for type-safe CSS.
* [swift-html](https://www.github.com/coenttb/swift-html): A Swift DSL for type-safe HTML & CSS, integrating [swift-css](https://www.github.com/coenttb/swift-css) and [pointfree-html](https://www.github.com/coenttb/pointfree-html).
* [swift-web](https://www.github.com/coenttb/swift-web): Foundational tools for web development in Swift.
* [coenttb-html](https://www.github.com/coenttb/coenttb-html): Builds on [swift-html](https://www.github.com/coenttb/swift-html), and adds functionality for HTML, Markdown, Email, and printing HTML to PDF.
* [coenttb-web](https://www.github.com/coenttb/coenttb-web): Builds on [swift-web](https://www.github.com/coenttb/swift-web), and adds functionality for web development.
* [coenttb-server](https://www.github.com/coenttb/coenttb-server): Build fast, modern, and safe servers that are a joy to write. `coenttb-server` builds on [coenttb-web](https://www.github.com/coenttb/coenttb-web), and adds functionality for server development.
* [coenttb-vapor](https://www.github.com/coenttb/coenttb-server-vapor): `coenttb-server-vapor` builds on [coenttb-server](https://www.github.com/coenttb/coenttb-server), and adds functionality and integrations with Vapor and Fluent.
* [coenttb-com-server](https://www.github.com/coenttb/coenttb-com-server): The backend server for coenttb.com, written entirely in Swift and powered by [coenttb-server-vapor](https://www.github.com/coenttb-server-vapor).

### PointFree foundations
* [coenttb/pointfree-html](https://www.github.com/coenttb/pointfree-html): A Swift DSL for type-safe HTML, forked from [pointfreeco/swift-html](https://www.github.com/pointfreeco/swift-html) and updated to the version on [pointfreeco/pointfreeco](https://github.com/pointfreeco/pointfreeco).
* [coenttb/pointfree-web](https://www.github.com/coenttb/pointfree-html): Foundational tools for web development in Swift, forked from  [pointfreeco/swift-web](https://www.github.com/pointfreeco/swift-web).
* [coenttb/pointfree-server](https://www.github.com/coenttb/pointfree-html): Foundational tools for server development in Swift, forked from  [pointfreeco/swift-web](https://www.github.com/pointfreeco/swift-web).

## Known Issues

### WebKit Process Assertion Warnings

When running tests or using this library in a command-line environment, you may see warnings like:

```
Error acquiring assertion: <Error Domain=RBSServiceErrorDomain Code=1 
"(target is not running or doesn't have entitlement com.apple.runningboard.assertions.webkit AND 
originator doesn't have entitlement com.apple.runningboard.assertions.webkit)" 
UserInfo={NSLocalizedFailureReason=(target is not running or doesn't have entitlement 
com.apple.runningboard.assertions.webkit AND originator doesn't have entitlement 
com.apple.runningboard.assertions.webkit)}>
```

#### Why This Happens

These warnings occur because:

1. **WebKit in Non-UI Contexts**: This library uses WKWebView to render HTML to PDF, which is designed for use in UI applications, not command-line or test environments.

2. **RunningBoard Service**: macOS uses RunningBoard Service (RBS) to manage process lifecycles. When WebKit processes start in a non-UI context, RBS tries to create process assertions but cannot because the process lacks the required entitlements.

3. **Missing Entitlements**: The `com.apple.runningboard.assertions.webkit` entitlement is needed to properly manage WebKit processes, but is only available to proper UI applications.

#### Impact

Despite these warnings, the library should still function correctly. These messages are warnings, not errors, and don't prevent the PDF generation from working.

#### Potential Solutions

If these warnings are problematic:

1. **Use in a UI Application**: Use this library in a proper UI application context where entitlements can be properly assigned.

2. **Create Test Mocks**: For testing, create mock implementations that don't use real WebKit processes.

3. **Custom Test Runner**: Run tests inside a properly entitlemented app bundle rather than directly.

## CI/CD Status

This project uses GitHub Actions for continuous integration and deployment:

- **Continuous Integration**: Runs on every push and PR to ensure code quality
- **Multi-Platform Testing**: Tests on macOS, iOS (Mac Catalyst), Linux, and Windows
- **Performance Monitoring**: Automated benchmarks track performance across releases
- **Documentation**: Automatic documentation generation with DocC
- **Dependency Updates**: Dependabot keeps dependencies current

## Installation

To install the package, add the following line to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/coenttb/swift-html-to-pdf.git", from: "0.5.0")
]
```

You can then make HtmlToPdf available to your Package's target by including HtmlToPdf in your target's dependencies as follows:
```swift
targets: [
    .target(
        name: "TheNameOfYourTarget",
        dependencies: [
            .product(name: "HtmlToPdf", package: "swift-html-to-pdf")
        ]
    )
]
```
