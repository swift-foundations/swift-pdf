# Metrics Integration Fix Plan

## Executive Summary

**Problem:** Trying to use `swift-metrics` types (`Counter`/`Timer`/`Gauge`) directly as dependencies is fundamentally incompatible with `swift-dependencies` architecture.

**Root Causes (Verified from Source Code):**

1. **swift-metrics design** (from `apple/swift-metrics`):
   - Global singleton `MetricsSystem.factory` for entire process
   - `Counter` is a `class` that **captures and stores** `CounterHandler` at creation
   - Handler is a `let` property that **can never be changed**
   - Designed for **server applications** with one backend per process
   - Quote from docs: "Libraries should never change the metrics implementation"

2. **swift-dependencies design** (from `pointfreeco/swift-dependencies`):
   - Task-local `@TaskLocal DependencyValues._current` for per-test isolation
   - `.dependencies` trait creates **fresh `DependencyValues()` per test**
   - Dependencies are **structs with closures**, not stateful classes
   - Designed for **libraries** that need different implementations per context
   - Quote from docs: "Use a struct with closure properties to represent the interface"

3. **The incompatibility:**
   - Static `testValue` evaluated **once globally** (Swift 6.2+), creates `Counter` with NOP handler
   - Test's `init()` calls `MetricsSystem.bootstrapInternal()`, but **existing Counters don't see it**
   - `.dependencies` trait creates fresh dependency values, but Counters are **permanently bound to old handlers**

**Solution:** Use the `@DependencyClient` pattern (already used for `PDF.Render.Client`):
- Change `PDF.Render.Metrics` from storing `Counter`/`Timer`/`Gauge` to storing closures
- Follows **exact same pattern** as existing `PDF.Render.Client` in the codebase
- Live implementation: closures delegate to swift-metrics
- Test implementation: closures update in-memory storage
- No changes to usage code - same API, different implementation

**Recommendation:** Implement Option 4 - the **only** approach that:
1. Is compatible with both swift-metrics and swift-dependencies architectures
2. Follows the existing domain-first pattern in the codebase
3. Provides the same file organization as `PDF.Render.Client`

---

## Current Status: BROKEN ❌

**Test Results:**
- ✅ `MetricsTests` (7/7 passing) - Basic metrics structure works
- ❌ `MetricsIntegrationTests` (1/10 passing) - Actual metrics collection **completely broken**

**Key Issue:** Metrics are NOT being captured. Counters return `nil`, meaning `TestMetricsBackend` isn't receiving any metrics from production code.

## Root Cause Analysis

After studying `swift-dependencies` source code, here's what's actually happening:

### How swift-dependencies ACTUALLY Works

1. **`DependencyValues` is a `@TaskLocal`**:
   ```swift
   public struct DependencyValues: Sendable {
     @TaskLocal public static var _current = Self()
   }
   ```

2. **The `.dependencies` trait (Swift 6.1+)**:
   ```swift
   public func provideScope(...) async throws {
     try await withDependencies {
       if Self.isRoot {
         $0 = DependencyValues()  // ← Fresh DependencyValues per test!
       }
       try await updateValues(&$0)
     } operation: {
       try await function()
     }
   }
   ```
   **Key insight**: The `.dependencies` trait creates a **fresh `DependencyValues()` instance** for each test when `isRoot == true`.

3. **`@Dependency` property wrapper captures initial values**:
   ```swift
   public init(_ keyPath: KeyPath<DependencyValues, Value> & Sendable, ...) {
     self.initialValues = DependencyValues._current  // ← Captures at init time!
     self.keyPath = keyPath
   }

   fileprivate var _wrappedValue: Value {
     let dependencies = self.initialValues.merging(DependencyValues._current)
     return DependencyValues.$_current.withValue(dependencies) {
       DependencyValues._current[keyPath: self.keyPath]
     }
   }
   ```
   **Key insight**: `@Dependency` captures `initialValues` when the property wrapper is initialized, then **merges** them with the current task-local values on access.

### The Problem with Global MetricsSystem

There's a fundamental mismatch between:

1. **swift-metrics**: Global singleton `MetricsSystem.factory`
2. **swift-dependencies**: Task-local `@TaskLocal DependencyValues._current`
3. **Swift Testing 6.2+**: Static `.testValue` evaluated once globally

### The Actual Flow (What's Broken)

```swift
// 1. Swift Testing starts, evaluates static testValue ONCE globally
extension PDF.Render.Metrics: TestDependencyKey {
    public static var testValue: Self {
        PDF.Render.Metrics()  // ← Creates Counter/Timer/Gauge
        // These call MetricsSystem.factory... which is NOT bootstrapped yet!
        // They get NOPMetricsHandler by default
    }
}

// 2. Test suite init() runs (per test, due to .dependencies trait)
@Suite("Metrics Integration", .dependencies, .serialized)
struct MetricsIntegrationTests {
    let metricsBackend: TestMetricsBackend

    init() {
        let backend = TestMetricsBackend()
        MetricsSystem.bootstrapInternal(backend)  // ← TOO LATE! Metrics already created
        self.metricsBackend = backend
    }
}

// 3. Test runs with .dependencies trait
@Test func test() async throws {
    // .dependencies trait creates fresh DependencyValues()
    @Dependency(\.pdf) var pdf

    // pdf.render.metrics contains Counter instances created in step 1
    // Those Counters STILL use the old factory (NOP), not our backend!
    try await pdf.render.client.html(html, to: output)
}

// 4. Production code records metrics
@Dependency(\.pdf.render.metrics) var metrics
metrics.pdfsGenerated.increment()  // ← Increments... into the void (NOP handler)

// 5. Test assertions fail
let counter = metricsBackend.counter("htmltopdf_pdfs_generated_total")
#expect(counter?.value == 1)  // ← FAILS: counter is nil!
```

### Why It's Fundamentally Broken

**The Core Issue:**
- `Counter`, `Timer`, `Gauge` capture `MetricsSystem.factory` **at creation time**
- Once created, they cannot be "re-wired" to a different factory
- The `.dependencies` trait creates fresh `DependencyValues`, but the **metrics objects inside** are still the same old instances

**Proof from swift-metrics source:**
```swift
// From swift-metrics/Sources/CoreMetrics/Metrics.swift
public struct Counter {
    let handler: CounterHandler  // ← Captured at init, never changes!

    public init(label: String, dimensions: [(String, String)] = []) {
        self.handler = MetricsSystem.factory.makeCounter(label: label, dimensions: dimensions)
    }

    public func increment(by amount: Int64 = 1) {
        self.handler.increment(by: amount)  // ← Always uses original handler
    }
}
```

**Why Our Approach Fails:**
1. `PDF.Render.Metrics.testValue` creates metrics **globally, once**
2. Those metrics capture `MetricsSystem.factory` (which is NOP by default)
3. Test's `init()` bootstraps a new factory, but **existing metrics don't see it**
4. The `.dependencies` trait creates fresh `DependencyValues`, but `testValue` is **not re-evaluated**
5. Production code uses the old metrics with NOP handlers
6. Our `TestMetricsBackend` never receives anything

**Global State Battle:**
- `MetricsSystem.factory` is a **global var** that can only be set once (or via `bootstrapInternal()`)
- `DependencyValues._current` is a **`@TaskLocal`** that creates fresh instances per test
- Metrics objects **bridge** between these two worlds, but capture at creation time
- Once the bridge is built (metrics created), it can't be rebuilt

## Solution Options

### Option 1: Bootstrap-Before-TestValue Pattern

**Idea:** Bootstrap `MetricsSystem` before `testValue` is evaluated

**Problem:** Swift 6.2+ evaluates static `testValue` lazily on first access, which is **unpredictable**.

**Attempted Fix:**
```swift
@Suite(.dependencies)
struct MetricsIntegrationTests {
    init() {
        // Bootstrap FIRST
        let backend = TestMetricsBackend()
        MetricsSystem.bootstrapInternal(backend)

        // Then access dependencies to trigger testValue evaluation
        withDependencies {
            $0.pdf.render.metrics = PDF.Render.Metrics()  // Create fresh!
        } operation: {
            // Nothing
        }
    }
}
```

**Verdict:** ❌ **Doesn't work** because:
1. `testValue` may be evaluated before `init()` even runs
2. Even if we create fresh metrics in `init()`, the `.dependencies` trait creates **new** `DependencyValues()` which calls `testValue` again
3. Requires manual `withDependencies` in every test
4. Fighting the framework instead of working with it

---

### Option 2: Lazy Metrics Creation

**Idea:** Don't create `Counter`/`Timer`/`Gauge` in `Metrics.init()`, create them lazily on first access

**Implementation:**
```swift
public struct Metrics: Sendable {
    public var pdfsGenerated: Counter {
        Counter(label: "htmltopdf_pdfs_generated_total")
    }
    // Each access creates a NEW Counter!
}
```

**Verdict:** ❌ **Worse** because:
1. Each access creates a **different** `Counter` instance
2. The first `Counter` increments to 1, the second `Counter` (different instance) reads 0
3. Metrics are supposed to be singleton-like accumulators, not disposable values
4. Completely breaks the swift-metrics design

---

### Option 3: Global MetricsSystem with Manual Test Setup

**Idea:** Accept that metrics are global, make tests work around it

**Implementation:**
```swift
@Test func test() {
    // Manually bootstrap in EVERY test
    let backend = TestMetricsBackend()
    MetricsSystem.bootstrapInternal(backend)

    // Manually create fresh metrics AFTER bootstrap
    withDependencies {
        $0.pdf.render.metrics = PDF.Render.Metrics()
    } operation: {
        @Dependency(\.pdf) var pdf
        // Test...
    }

    // Assert
    #expect(backend.counter("...")?.value == 1)
}
```

**Verdict:** ❌ **Fragile** because:
1. Requires boilerplate in **every single test**
2. Easy to forget, leading to mysterious failures
3. Doesn't work with parameterized tests
4. The `.dependencies` trait resets `DependencyValues()`, undoing our manual setup
5. Goes against swift-dependencies philosophy

---

### Option 4: Dependency-Based Metrics Client (RECOMMENDED) ✅

**Core Insight:** Don't fight the frameworks - embrace the Dependencies pattern fully!

**The Key Realization:**
- `swift-dependencies` is designed for **struct-based dependencies with closures**, not globals
- From their docs: "Rather than designing the dependency as a protocol, we can use a struct with closure properties"
- This is exactly the `@DependencyClient` pattern they recommend

**Why This Works:**
- Each test gets a fresh `DependencyValues()` via `.dependencies` trait
- The metrics client is just data (closures), not stateful objects with global handlers
- No `MetricsSystem.bootstrap()` needed in tests
- Production still uses swift-metrics, tests use in-memory storage

**Pros:**
- ✅ Perfect test isolation (automatic via `.dependencies` trait)
- ✅ No global state battles
- ✅ Follows swift-dependencies design philosophy
- ✅ Works naturally with Swift Testing 6.2+
- ✅ Clean separation: production code uses swift-metrics, tests don't
- ✅ Each test gets truly fresh metrics (no manual reset needed)

**Cons:**
- More upfront work (rewrite metrics as client pattern)
- Different API from raw swift-metrics (but same concepts)

#### Architecture

**Domain-First Pattern (Existing Codebase Style):**

```
PDF (domain)
└── Render (capability)
    ├── Client (operations via @DependencyClient)
    ├── Configuration (settings)
    └── Metrics (observability)  ← Currently broken, needs same pattern as Client

Current structure:
- PDF.swift: Main domain type with `var render: Render`
- PDF.Render.swift: Capability with `var client: Client`, `var configuration: Configuration`, `var metrics: Metrics`
- PDF.Render.Client.swift: @DependencyClient with operations as closures
- PDF.Render.Client+macOS.swift: DependencyKey with liveValue
- PDF.Render+TestDependencyKey.swift: TestDependencyKey with testValue
```

**Metrics Should Follow Same Pattern:**

```
┌─────────────────────────────────────────────────────────┐
│ PDF.Render.Metrics (should be @DependencyClient)        │
├─────────────────────────────────────────────────────────┤
│ Current (BROKEN):                                       │
│ - struct with Counter/Timer/Gauge properties           │
│ - Captures swift-metrics handlers at creation          │
│ - Can't be re-wired per test                           │
│                                                         │
│ Should be (WORKS):                                      │
│ - @DependencyClient with closure properties            │
│ - Live: closures delegate to swift-metrics             │
│ - Test: closures update in-memory storage              │
└─────────────────────────────────────────────────────────┘
```

#### Implementation Plan

Following the existing domain-first pattern in the codebase.

##### Phase 1: Update PDF.Render.Metrics to Use @DependencyClient

**File:** `Sources/HtmlToPdf/PDF.Render.Metrics.swift` (replace existing)

```swift
//
//  PDF.Render.Metrics.swift
//  swift-html-to-pdf
//
//  Metrics for PDF rendering observability
//

import Dependencies
import DependenciesMacros
import Foundation

extension PDF.Render {
    /// Metrics for PDF rendering operations
    ///
    /// Following the domain-first pattern where Metrics is a capability
    /// with operations defined as dependency endpoints for testability.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// @Dependency(\.pdf.render.metrics) var metrics
    ///
    /// metrics.recordSuccess(duration: duration, mode: .paginated)
    /// metrics.recordFailure(error: error)
    /// ```
    @DependencyClient
    public struct Metrics: @unchecked Sendable {

        // MARK: - Counter Operations

        /// Increment PDFs generated counter
        @DependencyEndpoint
        public var incrementPDFsGenerated: @Sendable () -> Void

        /// Increment PDFs failed counter
        @DependencyEndpoint
        public var incrementPDFsFailed: @Sendable () -> Void

        /// Increment pool replacements counter
        @DependencyEndpoint
        public var incrementPoolReplacements: @Sendable () -> Void

        // MARK: - Timer Operations

        /// Record render duration
        @DependencyEndpoint
        public var recordRenderDuration: @Sendable (_ duration: Duration, _ mode: PDF.PaginationMode?) -> Void

        // MARK: - Gauge Operations

        /// Update pool utilization gauge
        @DependencyEndpoint
        public var updatePoolUtilization: @Sendable (_ count: Int) -> Void

        /// Update throughput gauge
        @DependencyEndpoint
        public var updateThroughput: @Sendable (_ pdfsPerSecond: Double) -> Void

        // MARK: - Convenience Methods

        /// Record successful PDF generation
        public func recordSuccess(duration: Duration, mode: PDF.PaginationMode? = nil) {
            incrementPDFsGenerated()
            recordRenderDuration(duration, mode)
        }

        /// Record PDF generation failure
        public func recordFailure(error: PrintingError? = nil) {
            incrementPDFsFailed()
        }

        /// Record pool replacement
        public func recordPoolReplacement() {
            incrementPoolReplacements()
        }
    }
}
```

##### Phase 2: Live Implementation (swift-metrics)

**File:** `Sources/HtmlToPdf/PDF.Render.Metrics+macOS.swift` (or `+Live.swift`)

Following the pattern from `PDF.Render.Client+macOS.swift`:

```swift
//
//  PDF.Render.Metrics+macOS.swift
//  swift-html-to-pdf
//
//  Live metrics implementation using swift-metrics
//

#if os(macOS) || os(iOS)
import Dependencies
import Metrics

extension PDF.Render.Metrics: DependencyKey {
    /// Live implementation delegating to swift-metrics
    ///
    /// This creates swift-metrics Counter/Timer/Gauge instances and delegates
    /// operations to them. Requires MetricsSystem.bootstrap() at app startup.
    public static var liveValue: Self {
        // Create swift-metrics instances (captured in closures)
        let pdfsGenerated = Counter(label: "htmltopdf_pdfs_generated_total")
        let pdfsFailed = Counter(label: "htmltopdf_pdfs_failed_total")
        let poolReplacements = Counter(label: "htmltopdf_pool_replacements_total")
        let renderDuration = Timer(label: "htmltopdf_render_duration_seconds")
        let poolUtilization = Gauge(label: "htmltopdf_pool_utilization")
        let currentThroughput = Gauge(label: "htmltopdf_throughput_pdfs_per_sec")

        return Self(
            incrementPDFsGenerated: { pdfsGenerated.increment() },
            incrementPDFsFailed: { pdfsFailed.increment() },
            incrementPoolReplacements: { poolReplacements.increment() },
            recordRenderDuration: { duration, mode in
                let nanoseconds = duration.components.seconds * 1_000_000_000 +
                                duration.components.attoseconds / 1_000_000_000
                if let mode = mode {
                    Timer(
                        label: "htmltopdf_render_duration_seconds",
                        dimensions: [("mode", mode.metricsLabel)]
                    ).recordNanoseconds(nanoseconds)
                } else {
                    renderDuration.recordNanoseconds(nanoseconds)
                }
            },
            updatePoolUtilization: { count in poolUtilization.record(count) },
            updateThroughput: { pdfsPerSecond in currentThroughput.record(pdfsPerSecond) }
        )
    }
}
#endif
```

##### Phase 3: Test Implementation (In-Memory)

**File:** `Sources/PDFTestSupport/PDF.Render.Metrics+TestSupport.swift`

Following the pattern from existing test support:

```swift
//
//  PDF.Render.Metrics+TestSupport.swift
//  PDFTestSupport
//
//  Test implementation with in-memory storage
//

import Dependencies
import Foundation
@testable import HtmlToPdf

extension PDF.Render.Metrics: TestDependencyKey {
    /// Test value with isolated in-memory storage
    ///
    /// Each test gets a fresh instance automatically via .dependencies trait.
    /// No MetricsSystem.bootstrap() needed!
    public static var testValue: Self {
        // Return unimplemented - will fail if accessed without explicit override
        Self()
    }
}

/// Create test metrics with storage for assertions
public func makeTestMetrics() -> (metrics: PDF.Render.Metrics, storage: TestMetricsStorage) {
    let storage = TestMetricsStorage()

    let metrics = PDF.Render.Metrics(
        incrementPDFsGenerated: { storage.pdfsGenerated += 1 },
        incrementPDFsFailed: { storage.pdfsFailed += 1 },
        incrementPoolReplacements: { storage.poolReplacements += 1 },
        recordRenderDuration: { duration, mode in
            storage.renderDurations.append((duration, mode))
        },
        updatePoolUtilization: { count in storage.poolUtilization = count },
        updateThroughput: { throughput in storage.currentThroughput = throughput }
    )

    return (metrics, storage)
}

/// In-memory storage for test metrics
public final class TestMetricsStorage: Sendable {
    private let lock = NSLock()

    private var _pdfsGenerated: Int64 = 0
    private var _pdfsFailed: Int64 = 0
    private var _poolReplacements: Int64 = 0
    private var _renderDurations: [(Duration, PDF.PaginationMode?)] = []
    private var _poolUtilization: Int = 0
    private var _currentThroughput: Double = 0

    public init() {}

    public var pdfsGenerated: Int64 {
        get { lock.withLock { _pdfsGenerated } }
        set { lock.withLock { _pdfsGenerated = newValue } }
    }

    public var pdfsFailed: Int64 {
        get { lock.withLock { _pdfsFailed } }
        set { lock.withLock { _pdfsFailed = newValue } }
    }

    public var poolReplacements: Int64 {
        get { lock.withLock { _poolReplacements } }
        set { lock.withLock { _poolReplacements = newValue } }
    }

    public var renderDurations: [(Duration, PDF.PaginationMode?)] {
        get { lock.withLock { _renderDurations } }
        set { lock.withLock { _renderDurations = newValue } }
    }

    public var poolUtilization: Int {
        get { lock.withLock { _poolUtilization } }
        set { lock.withLock { _poolUtilization = newValue } }
    }

    public var currentThroughput: Double {
        get { lock.withLock { _currentThroughput } }
        set { lock.withLock { _currentThroughput = newValue } }
    }

    // Computed properties
    public var p95Duration: Duration? {
        let durations = renderDurations.map { $0.0 }.sorted()
        guard !durations.isEmpty else { return nil }
        let index = Int(Double(durations.count) * 0.95)
        return durations[min(index, durations.count - 1)]
    }

    public func reset() {
        lock.withLock {
            _pdfsGenerated = 0
            _pdfsFailed = 0
            _poolReplacements = 0
            _renderDurations = []
            _poolUtilization = 0
            _currentThroughput = 0
        }
    }
}
```

##### Phase 4: Update Production Code

**Changes to:** `Sources/HtmlToPdf/PDF.Render.Client+macOS.swift`

```diff
- @Dependency(\.pdf.render.metrics) var metrics
+ @Dependency(\.pdfMetrics) var metrics

  // Record metrics for successful PDF generation
  metrics.recordSuccess(duration: duration, mode: mode)
```

Same for:
- `Sources/HtmlToPdf/PDF.Render.Client+iOS.swift`
- `Sources/HtmlToPdf/WebViewPoolClient-ResourcePool.swift`

##### Phase 5: Update Tests

**Changes to:** `Tests/HtmlToPdfTests/MetricsIntegrationTests.swift`

Following the existing test pattern with `.dependencies` trait:

```swift
import Testing
import Dependencies
@testable import HtmlToPdf
import PDFTestSupport

@Suite("Metrics Integration", .dependencies)
struct MetricsIntegrationTests {
    let metricsStorage: TestMetricsStorage

    init() {
        // Create test metrics with storage
        let (metrics, storage) = makeTestMetrics()
        self.metricsStorage = storage

        // Override metrics dependency for this suite
        withDependencies {
            $0.pdf.render.metrics = metrics
        } operation: {
            // Suite initialization complete
        }
    }

    @Test("Metrics record PDF generation success")
    func metricsRecordSuccess() async throws {
        @Dependency(\.pdf) var pdf

        try await withTemporaryDirectory { output in
            let html = "<html><body><h1>Test Document</h1></body></html>"
            _ = try await pdf.render.client.html(html, to: output.appendingPathComponent("test.pdf"))

            // Assert on storage directly
            #expect(metricsStorage.pdfsGenerated == 1)
            #expect(metricsStorage.renderDurations.count == 1)
            #expect(metricsStorage.pdfsFailed == 0)
        }
    }

    @Test("Metrics record PDF generation failure")
    func metricsRecordFailure() async throws {
        @Dependency(\.pdf) var pdf

        try await withTemporaryDirectory { output in
            let badHtml = "<html><body><img src='nonexistent.png'></body></html>"

            await #expect(throws: Error.self) {
                _ = try await pdf.render.client.html(badHtml, to: output.appendingPathComponent("test.pdf"))
            }

            #expect(metricsStorage.pdfsFailed == 1)
            #expect(metricsStorage.pdfsGenerated == 0)
        }
    }
}
```

##### Phase 6: Backwards Compatibility (Optional)

Keep old `PDF.Render.Metrics` as thin wrapper:

```swift
extension PDF.Render {
    /// Legacy Metrics type for backwards compatibility
    ///
    /// **Deprecated**: Use MetricsClient via @Dependency(\.pdfMetrics) instead
    @available(*, deprecated, message: "Use MetricsClient via @Dependency(\\.pdfMetrics)")
    public struct Metrics: Sendable {
        public let pdfsGenerated: Counter
        public let pdfsFailed: Counter
        // ... etc

        public init() {
            self.pdfsGenerated = Counter(label: "htmltopdf_pdfs_generated_total")
            // ... etc
        }
    }
}
```

## Migration Checklist

- [ ] Phase 1: Update `PDF.Render.Metrics` to use `@DependencyClient`
- [ ] Phase 2: Create `PDF.Render.Metrics+macOS.swift` with `liveValue` using swift-metrics
- [ ] Phase 3: Create `PDF.Render.Metrics+TestSupport.swift` with `makeTestMetrics()` helper
- [ ] Phase 4: Update production code to use closure-based metrics (no changes needed - same API!)
- [ ] Phase 5: Update tests to use `makeTestMetrics()` pattern
- [ ] Run full test suite
- [ ] Remove old `MetricsSystem.bootstrap()` code from tests
- [ ] Clean up `TestMetricsBackend` (no longer needed)

## How This Follows Existing Codebase Patterns

The solution aligns perfectly with the existing domain-first architecture:

### Current Pattern (PDF.Render.Client)

```swift
// 1. Domain capability
extension PDF.Render {
    @DependencyClient
    public struct Client: @unchecked Sendable {
        @DependencyEndpoint
        public var documents: @Sendable (...) async throws -> AsyncThrowingStream<...>
    }
}

// 2. Live implementation (platform-specific)
#if os(macOS)
extension PDF.Render.Client: DependencyKey {
    public static var liveValue: Self { .macOS }
}
#endif

// 3. Test implementation
extension PDF.Render.Client: TestDependencyKey {
    public static let testValue = Self()  // Unimplemented
}

// 4. Usage
@Dependency(\.pdf.render.client) var client
try await client.documents(documents)
```

### New Pattern (PDF.Render.Metrics) - **EXACTLY THE SAME**

```swift
// 1. Domain capability (SAME PATTERN)
extension PDF.Render {
    @DependencyClient
    public struct Metrics: @unchecked Sendable {
        @DependencyEndpoint
        public var incrementPDFsGenerated: @Sendable () -> Void
    }
}

// 2. Live implementation (SAME PATTERN)
#if os(macOS)
extension PDF.Render.Metrics: DependencyKey {
    public static var liveValue: Self {
        // Closures delegate to swift-metrics
    }
}
#endif

// 3. Test implementation (SAME PATTERN)
extension PDF.Render.Metrics: TestDependencyKey {
    public static var testValue = Self()  // Unimplemented
}

// 4. Usage (SAME PATTERN)
@Dependency(\.pdf.render.metrics) var metrics
metrics.incrementPDFsGenerated()
```

### Key Consistency

| Aspect | PDF.Render.Client | PDF.Render.Metrics (Fixed) |
|--------|------------------|---------------------------|
| **Base Type** | `@DependencyClient struct` | `@DependencyClient struct` ✅ |
| **Operations** | `@DependencyEndpoint` closures | `@DependencyEndpoint` closures ✅ |
| **Live Implementation** | Platform-specific `+macOS.swift` | Platform-specific `+macOS.swift` ✅ |
| **Test Implementation** | `TestDependencyKey` with `testValue` | `TestDependencyKey` with `testValue` ✅ |
| **Access Pattern** | `@Dependency(\.pdf.render.client)` | `@Dependency(\.pdf.render.metrics)` ✅ |
| **File Organization** | Separate files for impl/tests | Separate files for impl/tests ✅ |

The only difference is what the closures delegate to:
- **Client**: Platform APIs (WKWebView, UIPrintPageRenderer)
- **Metrics**: swift-metrics in production, in-memory storage in tests

## Expected Outcomes

After this migration:

✅ **All tests pass** - Full isolation, no global state issues
✅ **Consistent architecture** - Metrics follows same pattern as Client
✅ **Clean production code** - No test infrastructure mixed in
✅ **Easy to test** - Just use `makeTestMetrics()` helper
✅ **Follows Dependencies pattern** - `@DependencyClient` with closures
✅ **Swift Testing compatible** - Works naturally with Swift 6.2+
✅ **No bootstrap hacks** - No `bootstrapInternal()` or timing dependencies
✅ **Type-safe** - Compile-time guarantees for metrics usage
✅ **Same file organization** - Matches existing Client pattern

## Why Option 4 is The Only Real Solution

After studying how `swift-dependencies` actually works, it's clear that:

### The Framework's Design

1. **`@TaskLocal` for isolation**: `DependencyValues._current` is task-local, creating fresh instances per test via `.dependencies` trait

2. **Struct-based dependencies**: The framework is designed for dependencies that are **data** (closures in structs), not stateful objects with global singletons

3. **Test trait creates fresh values**: Each test gets `DependencyValues()` which re-evaluates dependency values

### Why Global swift-metrics Can't Work

1. **Capture at creation**: `Counter`/`Timer`/`Gauge` capture `MetricsSystem.factory` when created, can't be changed later

2. **Static testValue evaluated once**: Swift 6.2+ lazily evaluates `static let testValue` once globally, not per-test

3. **Timing is unpredictable**: No guarantee when `testValue` is evaluated vs when `init()` runs

4. **The `.dependencies` trait fights it**: Creates fresh `DependencyValues()` which calls `testValue` again, but that still returns the same global instance

### The Solution: Embrace the Pattern

**Just follow swift-dependencies' own guidance:**

From their docs (DesigningDependencies.md):
> "Rather than designing the dependency as a protocol, we can use a struct with closure properties to represent the interface"

This is **exactly** what `@DependencyClient` macro is for!

```swift
@DependencyClient
struct MetricsClient {
    var incrementPDFsGenerated: () -> Void
    var recordRenderDuration: (Duration) -> Void
    // ... closures, not stateful objects!
}
```

Each test gets a **fresh struct** with **fresh closures** that point to **fresh storage**.
No globals. No timing issues. No `MetricsSystem.bootstrap()` battles.

## Implementation Recommendation

**Go with Option 4: Dependency-Based Metrics Client**

This is the **only** approach that:
- ✅ Works with swift-dependencies' actual architecture
- ✅ Works with Swift Testing's `.dependencies` trait
- ✅ Provides true test isolation automatically
- ✅ Requires no manual setup in each test
- ✅ Follows the framework's intended design patterns
- ✅ Maintains swift-metrics integration for production

All other options fight the frameworks instead of working with them.

---

## Key Learnings from swift-dependencies Source Code

### How `.dependencies` Trait Actually Works

From `Sources/DependenciesTestSupport/TestTrait.swift`:

```swift
public struct _DependenciesTrait: TestScoping, TestTrait, SuiteTrait {
    public func provideScope(...) async throws {
        try await withDependencies {
            if Self.isRoot {
                $0 = DependencyValues()  // ← FRESH instance per test!
            }
            try await updateValues(&$0)
        } operation: {
            try await function()
        }
    }
}
```

**Key insight**: When you use `@Suite(.dependencies)`, each test gets a **completely fresh `DependencyValues()` instance**. This is task-local via `@TaskLocal`.

### How `@Dependency` Property Wrapper Works

From `Sources/Dependencies/Dependency.swift`:

```swift
@propertyWrapper
public struct Dependency<Value>: Sendable {
    let initialValues: DependencyValues  // ← Captured at init!
    private let keyPath: KeyPath<DependencyValues, Value> & Sendable

    public init(_ keyPath: KeyPath<DependencyValues, Value> & Sendable, ...) {
        self.initialValues = DependencyValues._current  // ← Captures NOW
        self.keyPath = keyPath
    }

    fileprivate var _wrappedValue: Value {
        let dependencies = self.initialValues.merging(DependencyValues._current)
        return DependencyValues.$_current.withValue(dependencies) {
            DependencyValues._current[keyPath: self.keyPath]
        }
    }
}
```

**Key insights:**
1. `@Dependency` captures `DependencyValues._current` when the property wrapper is **initialized**
2. On access, it **merges** initial values with current task-local values
3. This allows dependencies to be overridden later with `withDependencies`

### How DependencyValues is Stored

From `Sources/Dependencies/DependencyValues.swift`:

```swift
public struct DependencyValues: Sendable {
    @TaskLocal public static var _current = Self()

    private var storage: [ObjectIdentifier: any Sendable] = [:]

    public init() { ... }
}
```

**Key insight**: `DependencyValues._current` is a `@TaskLocal`, which means:
- Each async task can have its own value
- The `.dependencies` trait leverages this for per-test isolation
- Values are **inherited** by child tasks, but changes in child tasks don't affect parent

### Why swift-metrics Doesn't Fit

From `apple/swift-metrics` actual source code (`Sources/CoreMetrics/Metrics.swift`):

```swift
/// A global facility where the default metrics backend implementation is configured.
///
/// `MetricsSystem` is set up just once in a given program to create the desired metrics backend
/// implementation using `MetricsFactory`.
public enum MetricsSystem {
    private static let _factory = FactoryBox(NOOPMetricsHandler.instance)

    /// `bootstrap` can be called at maximum once in any given program, calling it more than once will
    /// lead to undefined behavior, most likely a crash.
    public static func bootstrap(_ factory: MetricsFactory) {
        self._factory.replaceFactory(factory, validate: true)
    }

    // for our testing we want to allow multiple bootstrapping
    internal static func bootstrapInternal(_ factory: MetricsFactory) {
        self._factory.replaceFactory(factory, validate: false)
    }

    public static var factory: MetricsFactory {
        self._factory.underlying
    }
}

public final class Counter {
    public let _handler: CounterHandler  // ← Stored property!
    @usableFromInline
    package let _factory: MetricsFactory
    public let label: String
    public let dimensions: [(String, String)]

    public convenience init(label: String, dimensions: [(String, String)] = []) {
        self.init(label: label, dimensions: dimensions, factory: MetricsSystem.factory)
    }

    public convenience init(label: String, dimensions: [(String, String)] = [], factory: MetricsFactory) {
        let handler = factory.makeCounter(label: label, dimensions: dimensions)  // ← Created here!
        self.init(label: label, dimensions: dimensions, handler: handler, factory: factory)
    }

    public init(label: String, dimensions: [(String, String)], handler: CounterHandler, factory: MetricsFactory) {
        self.label = label
        self.dimensions = dimensions
        self._handler = handler      // ← Stored forever!
        self._factory = factory
    }

    @inlinable
    public func increment<DataType: BinaryInteger>(by amount: DataType) {
        self._handler.increment(by: Int64(amount))  // ← Always uses same handler!
    }
}
```

**The incompatibility:**

1. **Global singleton factory**:
   - `MetricsSystem._factory` is a **global static** (process-wide singleton)
   - `bootstrap()` can only be called **once** per process (crashes if called again)
   - `bootstrapInternal()` allows re-bootstrapping for testing, BUT...

2. **Handler captured at creation**:
   - `Counter.init()` calls `factory.makeCounter(...)` to create a `CounterHandler`
   - This handler is **stored as a let property** (`self._handler = handler`)
   - It can **never be changed** after creation

3. **The timing problem**:
   - When `Counter(label: "...")` is called, it captures `MetricsSystem.factory` at **that moment**
   - If you later call `MetricsSystem.bootstrapInternal(newFactory)`, existing `Counter` instances **don't see it**
   - They continue using the handler from the old factory

**Why this breaks with swift-dependencies:**

```swift
// Swift 6.2+ evaluates static testValue ONCE globally
extension PDF.Render.Metrics: TestDependencyKey {
    public static var testValue: Self {
        PDF.Render.Metrics()  // ← Creates Counter(label: "...")
        // Counter captures MetricsSystem.factory (which is NOOPMetricsHandler)
        // Counter stores handler from NOP factory
    }
}

// Later, test runs
init() {
    let backend = TestMetricsBackend()
    MetricsSystem.bootstrapInternal(backend)  // ← Changes global factory
    // But Counter instances in testValue STILL have NOP handler!
}
```

**The fundamental incompatibility:**
- `MetricsSystem.factory` is a **global var** (process-wide singleton)
- `DependencyValues._current` is a **`@TaskLocal`** (task-scoped, fresh per test)
- `Counter`/`Timer`/`Gauge` **capture and store handlers** at init time
- Once created with a handler, they're **permanently bound** to that handler
- You cannot "re-wire" metrics to a new factory after creation

This is why trying to use swift-metrics directly with swift-dependencies' per-test isolation is architecturally impossible.

### The Right Pattern

From `Sources/Dependencies/Documentation.docc/Articles/DesigningDependencies.md`:

```swift
@DependencyClient
struct AudioPlayerClient {
    var loop: (_ url: URL) async throws -> Void
    var play: (_ url: URL) async throws -> Void
    var setVolume: (_ volume: Float) async -> Void
    var stop: () async -> Void
}
```

**Why this works:**
- It's just a struct with closures (pure data, no global state)
- Each test gets a **fresh struct instance** via `.dependencies` trait
- Closures can point to **different storage** in each test
- No timing issues - struct is created when dependency is accessed
- Perfectly compatible with `@TaskLocal` isolation

**For our metrics:**
```swift
@DependencyClient
struct MetricsClient {
    var incrementPDFsGenerated: @Sendable () -> Void
    var recordRenderDuration: @Sendable (Duration) -> Void
    // Live: closures call swift-metrics Counter/Timer
    // Test: closures update in-memory storage
}
```

This is **the way**.

---

## TL;DR: What We Learned

1. **swift-dependencies uses `@TaskLocal` for isolation**: Each test gets a fresh `DependencyValues()` instance
2. **The `.dependencies` trait is the key**: It creates `DependencyValues()` per test (Swift 6.1+)
3. **`@Dependency` merges initial + current values**: Allows overriding dependencies with `withDependencies`
4. **swift-metrics uses global singletons**: `Counter`/`Timer`/`Gauge` capture factory at creation, can't be changed
5. **These two patterns are incompatible**: Can't mix global state with task-local isolation
6. **The solution: struct with closures**: Follow `@DependencyClient` pattern from swift-dependencies docs
7. **Production keeps swift-metrics**: Live implementation delegates to real `Counter`/`Timer`/`Gauge`
8. **Tests use in-memory storage**: Test implementation updates simple counters/arrays
9. **Both share the same interface**: Closure-based API works for both use cases
10. **Zero manual setup in tests**: The `.dependencies` trait handles everything automatically

**Bottom line:** Stop fighting the frameworks. Use the patterns they're designed for.

---

## Architectural Comparison: swift-metrics vs swift-dependencies

| Aspect | swift-metrics | swift-dependencies |
|--------|---------------|-------------------|
| **Design Philosophy** | Global singleton for entire process | Task-local isolation per test/context |
| **Storage Mechanism** | `static let _factory` in `MetricsSystem` | `@TaskLocal static var _current` in `DependencyValues` |
| **Initialization** | `bootstrap()` once per process lifetime | Fresh `DependencyValues()` per test via `.dependencies` trait |
| **State Mutability** | Global factory can be changed (via `bootstrapInternal()`) | Each task gets its own isolated values |
| **Metric Objects** | `Counter`/`Timer` are **classes** with stored `handler` property | Dependencies are typically **structs** with closures |
| **Handler Binding** | Handler captured at creation, **never changes** | Closures can be different per dependency instance |
| **Intended Use Case** | Server applications with one backend for entire process | Libraries that need different implementations (live/preview/test) |
| **Testing Strategy** | Global backend + manual reset between tests | Automatic isolation via `@TaskLocal` + traits |
| **Thread Safety** | Read-write locks around global factory | Task-local storage (inherently isolated) |
| **Compatibility** | ❌ Incompatible with per-test isolation | ✅ Designed for per-test isolation |

### Why The Mismatch Matters

**swift-metrics assumes:**
- One metrics backend for the entire application
- Backend is set once at startup
- All metrics flow to the same destination
- Global state is acceptable (it's a server framework)

**swift-dependencies assumes:**
- Different implementations for different contexts (live/preview/test)
- Dependencies can be overridden at any scope
- Complete isolation between tests
- No global state (incompatible with testing)

**The conflict:**
```swift
// swift-metrics: "Create me once, use me everywhere"
let counter = Counter(label: "requests")
counter.increment()  // → Always goes to global MetricsSystem.factory

// swift-dependencies: "Create fresh instances per context"
@Dependency(\.pdf) var pdf  // → Different instance per test
pdf.render.metrics.pdfsGenerated.increment()  // → Should go to test-specific backend
```

When you try to use swift-metrics types (`Counter`/`Timer`/`Gauge`) inside swift-dependencies, you get:
- ❌ Global factory that can't be task-local
- ❌ Handlers captured at creation that can't be swapped
- ❌ Static `testValue` evaluated once, creating metrics with NOP handler
- ❌ Test bootstraps new factory, but existing metrics don't see it

**The solution:** Don't use swift-metrics types as dependencies. Use the `@DependencyClient` pattern instead.

---

## How swift-metrics Is Designed to Be Used

From the official swift-metrics README:

### Server Application Pattern (Correct Use)

```swift
import Metrics

// 1) Bootstrap ONCE at application startup
@main
struct MyApp {
    static func main() {
        MetricsSystem.bootstrap(PrometheusMetricsFactory())

        // 2) Create metrics anywhere in the app
        runServer()
    }
}

// 3) Metrics are global, shared across entire process
func handleRequest() {
    let counter = Counter(label: "requests_total")
    counter.increment()
    // All counters with same label share same handler
}
```

**Key points from the docs:**

> "Note: If you are building a **library**, you don't need to concern yourself with this section. It is the **end users of your library (the applications)** who will decide which metrics backend to use. **Libraries should never change the metrics implementation** as that is something owned by the application."

> "`bootstrap` can be called at maximum once in any given program, calling it more than once will lead to undefined behavior, most likely a crash."

> "This instructs the `MetricsSystem` to install `SelectedMetricsImplementation` as the metrics backend to use. **This should only be done once at the beginning of the program.**"

### Testing Pattern (Their Recommendation)

From their example implementations, they show:

```swift
// Test backend is installed ONCE per test suite
class SimpleMetricsLibrary: MetricsFactory {
    private var counters: [String: ExampleCounter] = [:]

    func makeCounter(label: String, dimensions: [(String, String)]) -> CounterHandler {
        let key = makeKey(label: label, dimensions: dimensions)
        if let existing = counters[key] {
            return existing
        }
        let counter = ExampleCounter(label, dimensions)
        counters[key] = counter
        return counter
    }

    // Shared state across all metrics!
}
```

**The problem for us:**
- They assume **one backend per process**
- Tests share the same global state
- You must **manually reset** between tests
- No automatic per-test isolation

**Their design is perfect for servers, but incompatible with swift-dependencies' per-test isolation.**

### Why Our Use Case Is Different

We're not building a server application. We're building a **library** that:
- ✅ Needs to work in SwiftUI previews (different backend than production)
- ✅ Needs isolated tests (each test gets fresh metrics)
- ✅ Uses swift-dependencies everywhere (task-local pattern)
- ✅ Needs multiple implementations (live uses swift-metrics, test uses in-memory)

**swift-metrics says: "Libraries should never change the metrics implementation"**

But swift-dependencies says: "Override implementations for different contexts"

These philosophies are **fundamentally incompatible**.

### The Resolution

**For Production:** Use swift-metrics inside the live implementation of our `MetricsClient`

```swift
extension PDF.Render.MetricsClient: DependencyKey {
    static var liveValue: Self {
        // Closures delegate to swift-metrics
        let counter = Counter(label: "htmltopdf_pdfs_generated_total")
        return Self(
            incrementPDFsGenerated: { counter.increment() },
            // ...
        )
    }
}
```

**For Tests:** Use in-memory storage, bypassing swift-metrics entirely

```swift
extension PDF.Render.MetricsClient: TestDependencyKey {
    static func test() -> (client: Self, storage: TestMetricsStorage) {
        let storage = TestMetricsStorage()
        return (
            Self(
                incrementPDFsGenerated: { storage.pdfsGenerated += 1 },
                // ...
            ),
            storage
        )
    }
}
```

**Result:**
- ✅ Production gets proper swift-metrics integration
- ✅ Tests get automatic isolation via swift-dependencies
- ✅ No fighting between global state and task-local state
- ✅ Each framework used for what it's designed for
