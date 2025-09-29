# Contributing to swift-html-to-pdf

Thank you for your interest in contributing to swift-html-to-pdf! We welcome contributions from the community.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/swift-html-to-pdf.git`
3. Create a feature branch: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Test your changes locally
6. Commit your changes
7. Push to your fork
8. Open a Pull Request

## Development Setup

### Prerequisites

- macOS 11.0+ or iOS 14.0+
- Xcode 16.0+
- Swift 6.0+

### Building

```bash
swift build
```

### Testing

Run all tests:
```bash
swift test
```

Run tests on iOS (Mac Catalyst):
```bash
xcodebuild test -scheme swift-html-to-pdf -destination 'platform=macOS,variant=Mac Catalyst'
```

### Local CI Testing

Before pushing, test that your changes will pass CI:

```bash
.github/scripts/test-locally.sh
```

## Code Style

- Follow Swift API Design Guidelines
- Use descriptive variable and function names
- Add documentation comments for public APIs
- Keep functions focused and small
- Write tests for new functionality

## Testing Guidelines

- Write tests for all new features
- Ensure existing tests pass
- Test on both macOS and iOS platforms
- Include edge cases in your tests
- Use the Swift Testing framework (not XCTest)

Example test:
```swift
import Testing
@testable import HtmlToPdf

@Test("Description of what you're testing")
func testFeature() async throws {
    // Arrange
    let html = "<html><body>Test</body></html>"

    // Act
    try await html.print(to: URL(...))

    // Assert
    #expect(FileManager.default.fileExists(atPath: ...))
}
```

## Pull Request Process

1. **Update documentation** for any changed functionality
2. **Add tests** for new features
3. **Update CHANGELOG.md** with your changes (under "Unreleased")
4. **Ensure CI passes** - all checks must be green
5. **Keep PRs focused** - one feature or fix per PR
6. **Write clear commit messages** following conventional commits:
   - `feat:` New feature
   - `fix:` Bug fix
   - `docs:` Documentation changes
   - `test:` Test additions/changes
   - `refactor:` Code refactoring
   - `perf:` Performance improvements

## Reporting Issues

### Bug Reports

When reporting bugs, please include:
- Swift and Xcode versions
- Platform (macOS/iOS)
- Minimal code to reproduce
- Expected vs actual behavior
- Any error messages

### Feature Requests

For feature requests, please describe:
- The problem you're trying to solve
- Your proposed solution
- Alternative solutions considered
- Platform considerations

## Performance Contributions

If you're working on performance improvements:
1. Include benchmark results
2. Test with large datasets (1000+ documents)
3. Monitor memory usage
4. Consider WebView pool optimizations

## Documentation

- Update README.md for user-facing changes
- Add inline documentation for public APIs
- Include code examples in documentation
- Update CHANGELOG.md

## Questions?

Feel free to open an issue for questions or reach out to the maintainers.

## License

By contributing, you agree that your contributions will be licensed under the Apache 2.0 License.