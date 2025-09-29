# GitHub Actions Workflows

This directory contains GitHub Actions workflows for continuous integration and deployment.

## Workflows

### CI (`ci.yml`)
Runs on every push to main and on pull requests. Tests the library on:
- **macOS**: Tests with multiple Xcode versions in debug and release modes
- **iOS (Mac Catalyst)**: Builds and tests iOS code via Mac Catalyst
- **Linux**: Attempts to build on Ubuntu (WebKit support may be limited)
- **Windows**: Attempts to build on Windows (WebKit not available)
- **Integration**: Runs comprehensive integration tests including batch printing and error handling
- **Documentation**: Builds DocC documentation

### Release (`release.yml`)
Triggered when a GitHub release is published. Performs:
- Validates semantic versioning
- Runs all tests in release mode
- Creates universal binary artifacts
- Publishes documentation to GitHub Pages
- Uploads release artifacts

### Performance Benchmark (`benchmark.yml`)
Runs on push to main and pull requests. Measures:
- PDF generation performance (1000 documents benchmark)
- WebView pool performance
- Memory usage under pressure
- Posts results as PR comment

### Swift Format (`swift-format.yml`)
Runs on pull requests that modify Swift files:
- Checks code formatting using swift-format
- Reports formatting issues
- Provides instructions for fixing issues locally

## Configuration

### Dependabot (`dependabot.yml`)
Automatically creates PRs for:
- Swift package updates (weekly)
- GitHub Actions updates (monthly)

## Running Workflows Locally

To test workflows locally, you can use [act](https://github.com/nektos/act):

```bash
# Run CI workflow
act -j macos

# Run with specific event
act pull_request

# Run with secrets
act -s GITHUB_TOKEN=your_token
```

## Required Secrets

No additional secrets are required. The workflows use the default `GITHUB_TOKEN` provided by GitHub Actions.

## Branch Protection

It's recommended to enable branch protection for `main` with:
- Require status checks to pass (CI workflow)
- Require branches to be up to date
- Require PR reviews before merging

## Monitoring

Check workflow status at: https://github.com/coenttb/swift-html-to-pdf/actions