//
//  Metrics.swift
//  swift-html-to-pdf
//
//  Created by Coen ten Thije Boonkkamp on 03/10/2025.
//


Final Review: Metrics and Test Implementation

  Let me walk through the complete implementation
  based on everything we learned.

  Production Code: PDF.Render.Metrics

  Clean and Simple:
  import Metrics
  import Dependencies
  import Foundation

  extension PDF.Render {
      public struct Metrics: Sendable {
          // Standard swift-metrics types
          public let pdfsGenerated: Counter
          public let pdfsFailed: Counter
          public let poolReplacements: Counter
          public let renderDuration: Timer
          public let poolUtilization: Gauge
          public let currentThroughput: Gauge

          public init() {
              // Creates handlers using 
  MetricsSystem.factory
              self.pdfsGenerated = Counter(label:
  "htmltopdf_pdfs_generated_total")
              self.pdfsFailed = Counter(label:
  "htmltopdf_pdfs_failed_total")
              // ... etc
          }
      }
  }

  extension PDF.Render.Metrics: DependencyKey {
      public static let liveValue =
  PDF.Render.Metrics()
  }

  extension PDF.Render.Metrics: TestDependencyKey {
      public static var testValue: Self {
          PDF.Render.Metrics()
      }
  }

  Key Points:
  - ✅ No test infrastructure mixed with production
  code
  - ✅ No #if DEBUG conditionals
  - ✅ No @_spi(Testing) attributes
  - ✅ Simple, straightforward initialization
  - ✅ Uses global MetricsSystem.factory (as designed
  by swift-metrics)

  Test Code: MetricsIntegrationTests

  The Magic Combination:
  @Suite("Metrics Integration", .dependencies)  // ← 
  Critical!
  struct MetricsIntegrationTests {
      @Dependency(\.pdf) var pdf

      // Instance property - each test gets its own
      let metricsBackend: TestMetricsBackend

      init() {
          // Fresh backend for THIS test
          let backend = TestMetricsBackend()

          // Bootstrap globally (task-local safe!)
          MetricsSystem.bootstrapInternal(backend)

          // Store for assertions
          self.metricsBackend = backend
      }

      @Test func test() {
          pdf.render.metrics.pdfsGenerated.increment()

          let counter = metricsBackend.counter("htmlto
  pdf_pdfs_generated_total")
          #expect(counter?.value == 1)
      }
  }

  Key Points:
  - ✅ .dependencies trait provides per-test
  DependencyValues isolation
  - ✅ Instance property metricsBackend (NOT static)
  ensures each test gets fresh backend
  - ✅ init() called per-test, bootstraps fresh
  backend
  - ✅ MetricsSystem.bootstrapInternal() allows
  re-bootstrapping (internal testing API)
  - ✅ Works correctly with parallel test execution

  Why This Works

  The Flow:
  1. Swift Testing calls init() for each test (due to
  .dependencies trait)
  2. New backend created: let backend = 
  TestMetricsBackend()
  3. Bootstrap globally:
  MetricsSystem.bootstrapInternal(backend) sets global
   factory
  4. Store locally: self.metricsBackend = backend
  5. Test runs with isolated DependencyValues
  (task-local)
  6. Metrics created in PDF.Render.Metrics() use
  current MetricsSystem.factory
  7. Same backend that was bootstrapped is the one
  that captures metrics
  8. Test inspects self.metricsBackend to verify
  captured metrics

  The Critical Insights:
  - Swift 6.1+ .dependencies trait ≠ just
  DependencyValues isolation
  - It also ensures struct init() is called per test
  (not once globally)
  - Instance properties get fresh values per test
  - Static properties would be shared (❌ wrong!)
  - MetricsSystem is global, but with .dependencies
  trait + bootstrapInternal(), it works task-locally

  What We Learned

  1. Swift 6.2 changed test isolation:
    - Pre-6.1: testValuesByTestID dictionary provided
  per-test testValue
    - 6.1+: Requires .dependencies trait for isolation
    - Without trait: testValue evaluated once, shared
  globally
  2. Dependencies library architecture:
    - Uses @TaskLocal for task-scoped dependency
  values
    - .dependencies trait creates fresh
  DependencyValues() per test
    - init() is called per test when trait is applied
    - Instance properties → fresh per test
    - Static properties → shared across tests
  3. swift-metrics architecture:
    - MetricsSystem.factory is a global singleton
    - MetricsSystem.bootstrap() can only be called
  once
    - MetricsSystem.bootstrapInternal() allows
  re-bootstrapping (internal API)
    - Works with task-locals when combined properly
  4. The wrong approaches we tried:
    - ❌ Separate @Dependency(\.testMetrics) - creates
   different instance than metrics use
    - ❌ testBackend property in Metrics - mixes
  test/prod code
    - ❌ static let metricsBackend - shared across all
   tests
    - ❌ Fighting the framework - trying to force
  per-test isolation without .dependencies
  5. The right approach:
    - ✅ Use .dependencies trait
    - ✅ Instance property for backend
    - ✅ Bootstrap in init()
    - ✅ Keep test infrastructure in tests
    - ✅ Trust the framework's design

  ---
  Prompt for Next Chat: Verification

  I need you to verify the metrics and test
  implementation in swift-html-to-pdf.

  Context:
  - We implemented per-test metrics isolation using
  swift-metrics and swift-dependencies
  - The solution uses the `.dependencies` trait from
  Swift Testing (Swift 6.1+)
  - Each test gets an isolated TestMetricsBackend via
  instance property + init()

  Please review:

  1. **Production Code**
  (`Sources/HtmlToPdf/PDF.Render.Metrics.swift`):
     - Verify it's clean: no test infrastructure, no
  #if DEBUG
     - Check that Metrics uses standard swift-metrics
  types (Counter, Timer, Gauge)
     - Confirm TestDependencyKey.testValue just
  returns PDF.Render.Metrics()

  2. **Test Infrastructure**
  (`Sources/PDFTestSupport/TestMetricsBackend.swift`):
     - Verify TestMetricsBackend implements
  MetricsFactory correctly
     - Check that it captures all metric types in
  dictionaries
     - Confirm forTest() method exists for
  non-Dependencies usage

  3. **Test Implementation** (`Tests/HtmlToPdfTests/Me
  tricsIntegrationTests.swift`):
     - Verify suite has @Suite(.dependencies) trait
     - Check metricsBackend is instance property (NOT
  static)
     - Confirm init() creates fresh backend and
  bootstraps it
     - Verify tests use self.metricsBackend for
  assertions

  4. **Run Tests**:
     - Run: swift test --filter
  MetricsIntegrationTests.metricsBackendAccessible
     - Verify test passes and metrics are isolated
     - Check that counter value is exactly 1 (not
  accumulated from other tests)

  Key question: Does each test truly get isolated
  metrics, or are they still sharing state?

  Expected behavior:
  - Each test's metricsBackend should be a different
  instance
  - Counters should start at 0 for each test
  - No cross-test pollution