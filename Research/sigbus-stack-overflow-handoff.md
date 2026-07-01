# SIGBUS Stack Overflow in PDF Markdown Rendering — Investigation Handoff

<!--
---
version: 1.0.0
last_updated: 2026-03-13
status: IN_PROGRESS
tier: 2
---
-->

## TL;DR

`swift test` in `swift-pdf` crashes with SIGBUS (signal 10 / `___chkstk_darwin`) when
rendering markdown-to-PDF. Three markdown unit tests all crash. The crash is a **stack
overflow** — the async task stack (~64KB under Swift Testing) is exhausted during
rendering. This document provides everything needed to investigate, diagnose, and fix
the root cause.

---

## 1. How to Reproduce

```bash
cd /Users/coen/Developer/swift-foundations/swift-pdf
swift test
```

Expected output (abbreviated):

```
Build complete!
error: Exited with unexpected signal code 10
Test Suite 'All tests' passed at ...
    Executed 0 tests, with 0 failures
◇ Test run started.
◇ Suite "Markdown to PDF Tests" started.
◇ Test "Basic markdown renders to PDF" started.
◇ Test "Markdown with tables renders to PDF" started.
◇ Test "Complex markdown document renders to PDF" started.
```

All three tests start but none complete. The process receives SIGBUS (signal 10).

The crash does NOT occur in the nested testing package (`Tests/Package.swift`) where
all 32 performance and snapshot tests pass. It only occurs in the parent package's
Apple Testing unit tests.

---

## 2. Architecture Overview

### 2.1 The Rendering Pipeline

The system uses a **format-independent rendering protocol** (`Rendering.Context`) that
enables the same view tree to render to different output formats:

```
Markdown String
    │
    ▼
SwiftMarkdown.Document(parsing:)        ← Apple's swift-markdown parser
    │
    ▼
HTMLConverter (visitor pattern)           ← Visits AST, produces HTML views
    │
    ▼
HTML.View tree                           ← Type-erased via HTML.AnyView
    │
    ▼
Rendering.View._render<C>(context:)      ← Static dispatch, C determines format
    │
    ├── C = HTML.Context      → HTML byte output
    └── C = PDF.HTML.Context  → PDF page output (this is the crash path)
```

### 2.2 Key Protocols

**`Rendering.View`** (`swift-rendering-primitives`):

```swift
// File: swift-primitives/swift-rendering-primitives/Sources/
//       Rendering Primitives Core/Rendering.View.swift

public protocol View: ~Copyable {
    associatedtype Body: View & ~Copyable
    @Builder var body: Body { get }
    static func _render<C: Context>(_ view: borrowing Self, context: inout C)
}

// Default: composite views recurse into body
extension Rendering.View where Body: Rendering.View {
    public static func _render<C: Rendering.Context>(
        _ view: borrowing Self, context: inout C
    ) {
        Body._render(view.body, context: &context)  // ← RECURSIVE
    }
}
```

**`Rendering.Context`** (`swift-rendering-primitives`):

```swift
// File: swift-primitives/swift-rendering-primitives/Sources/
//       Rendering Primitives Core/Rendering.Context.swift

public protocol Context: ~Copyable {
    mutating func text(_ content: borrowing String)
    mutating func lineBreak()
    mutating func thematicBreak()
    mutating func image(source: String, alt: String)
    mutating func pageBreak()

    mutating func set(attribute name: String, _ value: String?)
    mutating func add(`class` name: String)
    mutating func write(raw bytes: [UInt8])
    mutating func register(style:atRule:selector:pseudo:) -> String?

    static func _pushBlock(_ context: inout Self, role: Semantic.Block?, style: Style)
    static func _popBlock(_ context: inout Self)
    static func _pushInline(_ context: inout Self, role: Semantic.Inline?, style: Style)
    static func _popInline(_ context: inout Self)
    static func _pushList(_ context: inout Self, kind: Semantic.List, start: Int?)
    static func _popList(_ context: inout Self)
    static func _pushItem(_ context: inout Self)
    static func _popItem(_ context: inout Self)
    static func _pushLink(_ context: inout Self, destination: borrowing String)
    static func _popLink(_ context: inout Self)
    static func _pushAttributes(_ context: inout Self)
    static func _popAttributes(_ context: inout Self)
    static func _pushElement(_ context: inout Self, tagName:isBlock:isVoid:isPreElement:)
    static func _popElement(_ context: inout Self, isBlock: Bool)
    static func _pushStyle(_ context: inout Self)
    static func _popStyle(_ context: inout Self)
    mutating func apply(inlineStyle property: Any) -> Bool
}
```

### 2.3 Key Types in the Rendering Chain

| Type | Location | Role |
|------|----------|------|
| `Rendering.View` | `swift-rendering-primitives` | Format-independent view protocol |
| `Rendering._Tuple<each Content>` | `swift-rendering-primitives` | Flat variadic composition from builder |
| `Rendering.Builder` | `swift-rendering-primitives` | Result builder, variadic `buildBlock` |
| `Rendering.Context` | `swift-rendering-primitives` | Format-independent rendering target |
| `HTML.View` | `swift-html-rendering` | Refines `Rendering.View` for HTML domain |
| `HTML.AnyView` | `swift-html-rendering` | Type-erased `any HTML.View` wrapper |
| `HTML.Element.Tag<Content>` | `swift-html-rendering` | Concrete HTML element (div, p, h1, etc.) |
| `HTML.Styled<Content>` | `swift-html-rendering` | CSS property wrapper around content |
| `PDF.HTML.Context` | `swift-pdf-html-rendering` | `Rendering.Context` conformance for PDF |
| `Markdown.HTML` | `swift-markdown-html-rendering` | Markdown → HTML view conversion |
| `HTMLConverter` | `swift-markdown-html-rendering` | `SwiftMarkdown.MarkupVisitor` implementation |

### 2.4 File Locations

```
swift-primitives/swift-rendering-primitives/Sources/Rendering Primitives Core/
  Rendering.View.swift              — View protocol + default _render
  Rendering.Context.swift           — Context protocol + push/pop accessors
  Rendering.Builder.swift           — @resultBuilder, variadic buildBlock
  Rendering._Tuple.swift            — Flat variadic tuple composition

swift-foundations/swift-html-rendering/Sources/HTML Renderable/
  HTML.View.swift                   — HTML.View protocol (refines Rendering.View)
  HTML.Builder.swift                — HTML.Builder (extends Rendering.Builder)
  HTML.AnyView.swift                — Type-erased existential wrapper
  HTML.Element.swift                — HTML.Element.Tag<Content>
  HTML.Styled.swift                 — CSS property wrapper
  HTML.Context.swift                — HTML byte-output context
  _Tuple+HTML.swift                 — _Tuple: HTML.View conformance

swift-foundations/swift-pdf-html-rendering/Sources/PDF HTML Rendering/
  PDF.HTML.Context.swift            — @CoW context type
  PDF.HTML.Context+Rendering.swift  — Rendering.Context conformance (1095 lines)
  PDF.HTML.Configuration.swift      — PDF rendering configuration
  PDF.HTML.Render.Result.swift      — Rendering result + finalization
  HTML.Element.Tag+TagStyle.swift   — Tag-specific styling for PDF

swift-foundations/swift-markdown-html-rendering/Sources/Markdown HTML Rendering/
  Markdown.HTML.swift               — Entry point (callAsFunction)
  HTMLConverter.swift                — SwiftMarkdown MarkupVisitor → HTML.AnyView
  Markdown.HTML.Builder.swift       — String builder for markdown content

swift-foundations/swift-pdf/
  Tests/PDF Tests/PDF Tests.swift   — The 3 crashing tests
  Package.swift                     — Parent package
```

---

## 3. The Rendering.Builder and _Tuple Design

The result builder was redesigned to prevent stack overflow from binary tree nesting:

```swift
// File: swift-rendering-primitives/.../Rendering.Builder.swift

@resultBuilder
public enum Builder {
    // Single element — pass through
    public static func buildBlock<V>(_ v: V) -> V { v }

    // Multiple elements — flat variadic tuple (NOT binary tree)
    public static func buildBlock<each Content>(
        _ content: repeat each Content
    ) -> Rendering._Tuple<repeat each Content> {
        Rendering._Tuple(repeat each content)
    }

    // NO buildPartialBlock(accumulated:next:) — intentionally absent.
    // Binary nesting overflows at 70+ elements.
}
```

The `_Tuple` renders by iterating, not recursing:

```swift
// File: swift-rendering-primitives/.../Rendering._Tuple.swift

extension Rendering._Tuple: Rendering.View
where repeat each Content: Rendering.View {
    public typealias Body = Never

    public static func _render<C: Rendering.Context>(
        _ view: borrowing Self, context: inout C
    ) {
        func render<V: Rendering.View>(_ v: V, _ ctx: inout C) {
            V._render(v, context: &ctx)
        }
        repeat render(each view.content, &context)
    }
}
```

The `repeat render(each view.content, &context)` expansion — this is the first
thing to investigate. Does the Swift compiler expand this to sequential calls
(bounded stack depth) or does it generate recursive metadata walking (unbounded)?

---

## 4. The Markdown → HTML.AnyView Conversion

The `HTMLConverter` visits each markdown AST node and produces `HTML.AnyView`:

```swift
// File: swift-markdown-html-rendering/.../HTMLConverter.swift

struct HTMLConverter: SwiftMarkdown.MarkupVisitor {
    typealias Result = HTML.AnyView

    // Document: iterate children, compose via @HTML.Builder
    @HTML.Builder
    mutating func defaultVisit(_ markup: any SwiftMarkdown.Markup) -> HTML.AnyView {
        for child in markup.children {
            let html = visit(child)
            if previewOnly ? tableOfContents.count <= 1 : true {
                html
            }
        }
    }

    // Heading: wraps children in heading element
    mutating func visitHeading(_ heading: SwiftMarkdown.Heading) -> HTML.AnyView {
        let childrenHTML = HTML.AnyView {
            for child in heading.children {
                visit(child)
            }
        }
        configuration.elements.heading.render(.init(
            level: heading.level,
            id: slug,
            children: childrenHTML
        ))
    }

    // Paragraph: wraps children in <p>
    mutating func visitParagraph(_ paragraph: SwiftMarkdown.Paragraph) -> HTML.AnyView {
        let childrenHTML = HTML.AnyView {
            for child in paragraph.children {
                visit(child)
            }
        }
        configuration.elements.paragraph.render(.init(children: childrenHTML))
    }

    // ... every visitor method follows this pattern
}
```

**Critical observation**: The converter uses `for child in X.children { visit(child) }`
inside `@HTML.Builder` blocks. The `for` loop goes through `buildArray`, producing
`[HTML.AnyView]`. This means the children are NOT flat `_Tuple` types — they are
`Array<HTML.AnyView>`.

The entry point wraps everything:

```swift
// File: swift-markdown-html-rendering/.../Markdown.HTML.swift

func callAsFunction(
    @Markdown.HTML.Builder _ markdown: () -> String
) -> some HTML.View {
    let markdownString = markdown()
    var converter = HTMLConverter(...)
    let content = converter.visit(
        SwiftMarkdown.Document(parsing: markdownString, options: .parseBlockDirectives)
    )
    return ContentDivision {
        VStack(spacing: .rem(0.5)) {
            content       // ← HTML.AnyView wrapping the full document
        }
        .css.inlineStyle("mask-image", ...)
    }
    .css.display(.block)
}
```

### 4.1 View Nesting Depth Analysis

For the "Complex markdown document" test, the view nesting is roughly:

```
PDF.Document
  └─ HTML.Document
       └─ ContentDivision (→ body → Tag<Content>)
            └─ CSS (display: block)
                 └─ VStack (→ body → Tag<Content>)
                      └─ CSS (spacing)
                           └─ HTML.AnyView (document content)
                                └─ Array<HTML.AnyView> (from defaultVisit for-loop)
                                     ├─ AnyView(Heading { AnyView(Array<AnyView(Text)>) })
                                     ├─ AnyView(Paragraph { AnyView(Array<...>) })
                                     ├─ AnyView(Heading { ... })
                                     ├─ AnyView(OrderedList { AnyView(Array<AnyView(ListItem)>) })
                                     │    └─ each ListItem wraps children in AnyView(Array<...>)
                                     ├─ AnyView(CodeBlock { ... })
                                     ├─ AnyView(Table { ... })
                                     │    └─ rows → cells → each cell is AnyView(Array<...>)
                                     └─ ... more elements ...
```

Each `AnyView._render` opens the existential and calls `V._render(base, context:)`.
Each `HTML.Element.Tag._render` calls `context.push.element(...)`, renders content,
then `context.pop.element(...)`. The content rendering recurses through `_render`.

The deepest nesting path through a table cell might be:

```
PDF.Document._render                        frame 1
  HTML.Document._render                     frame 2
    ContentDivision._render → body          frame 3
      CSS._render → body                    frame 4
        Styled._render → body               frame 5
          Tag<Content>._render              frame 6  (div)
            VStack._render → body           frame 7
              CSS._render → body            frame 8
                Styled._render → body       frame 9
                  Tag<Content>._render      frame 10 (div)
                    AnyView._render         frame 11 (document)
                      Array._render         frame 12
                        AnyView._render     frame 13 (table)
                          Tag._render       frame 14 (heading renderer → div?)
                            ... table ...
                              Tag._render   frame 15 (table)
                                Tag._render frame 16 (thead)
                                  Tag._render frame 17 (tr)
                                    Tag._render frame 18 (th)
                                      AnyView._render frame 19
                                        Array._render frame 20
                                          AnyView._render frame 21
                                            Styled._render frame 22
                                              Tag._render frame 23
                                                Text._render frame 24
```

Each frame includes the function frame plus the `_render<C>` generic specialization.
Under debug builds (no inlining), each frame is likely 200–500 bytes. At 24+ levels
of nesting, that's 5–12KB per rendering path. The question is: what is the ACTUAL
frame size, and does it exceed the ~64KB async task stack?

---

## 5. Historical Context: Three Prior Fixes

The SIGBUS crash has been investigated before. Three root causes were identified and
fixed in prior sessions (2026-03-12). However, the crash persists. Understanding
what was fixed helps narrow the remaining cause.

### 5.1 Cause 1: `as?` Conformance Checking Recursion (FIXED)

**Problem**: `as?` casts on deeply nested `_Tuple` types caused O(N) recursion in
the Swift runtime's conformance checking.

**Fix**: Added `Rendering._TupleMarker` — unconditional marker protocol. Checking
`as? any Rendering._TupleMarker` resolves in O(1) regardless of nesting depth.

**Commit**: `16ce688` in swift-primitives

**Current status**: This fix is NOT present in the current codebase. A grep for
`_TupleMarker` across `swift-primitives` and `swift-foundations` returns zero results.
The fix was likely lost when the codebase was restructured to use pure static dispatch
through `Rendering.Context` (commit `40ca61d`).

**Relevance**: With `buildPartialBlock` removed and flat variadic `_Tuple`, deeply
nested binary trees should no longer exist. The `_TupleMarker` fix may no longer be
needed. BUT: verify that no code path still uses `as?` on tuple types.

### 5.2 Cause 2: Type Metadata Demangling Recursion (FIXED)

**Problem**: `buildPartialBlock(accumulated:next:)` produced left-associative binary
trees: `_Tuple<_Tuple<_Tuple<..., G>, H>, I>`. The Swift runtime's type metadata
demangling recursed through the nesting to resolve conformances.

**Fix**: Removed `buildPartialBlock` from `Rendering.Builder`. Compiler falls back to
variadic `buildBlock<each Content>` producing flat tuples.

**Commit**: `16ce688` in swift-primitives

**Current status**: PRESENT — `Rendering.Builder` does NOT have `buildPartialBlock`.
The builder uses variadic `buildBlock`. This fix is active.

### 5.3 Cause 3: Rendering Pipeline Stack Depth (FIXED, then superseded)

**Problem**: The rendering engine used mutual recursion between `renderHTMLView` and
`renderInnerContent` (8 mutually recursive functions). Each custom view nesting level
added 3–4 stack frames. Wrapper types added 2–3 each. These compounded.

**Fix**: Replaced with iterative `Stack<Dispatch>` worklist interpreter.

**Commit**: `e7bd156` in swift-foundations

**Current status**: This fix was SUPERSEDED by the pure `Rendering.Context` static
dispatch architecture (commit `40ca61d - Converge PDF.HTML rendering to Rendering.Context
static dispatch`). The old Mirror-based dynamic dispatch + worklist approach was
replaced entirely. The current code has NO `renderHTMLView`, NO `renderInnerContent`,
NO `iterativeDispatch`, NO `Dispatch` enum, NO worklist. Instead, it uses pure
static dispatch through the `Rendering.Context` protocol.

**The implication**: The static dispatch path introduced its own recursion through
`_render → body → _render → body → ...` chains. The worklist fix is gone, and the
recursion problem may have returned in a different form.

### 5.4 Research Document

Full analysis of the prior fixes: `/Users/coen/Developer/swift-institute/Research/worklist-rendering-dispatch.md`

---

## 6. The Current Rendering Path (Pure Static Dispatch)

After commit `40ca61d`, rendering goes through `Rendering.View._render<C>` with
`C = PDF.HTML.Context`. There is NO dynamic dispatch (Mirror, `as?`, existentials)
in the core rendering loop — except inside `HTML.AnyView._render` which opens the
existential.

### 6.1 How Each Type Renders

**Composite views** (custom views with a `body`):
```swift
// Default _render: recurse into body
extension Rendering.View where Body: Rendering.View {
    public static func _render<C>(_ view: borrowing Self, context: inout C) {
        Body._render(view.body, context: &context)  // RECURSIVE CALL
    }
}
```

**`_Tuple`** (builder output):
```swift
// Iterate children via parameter pack expansion
public static func _render<C>(_ view: borrowing Self, context: inout C) {
    func render<V: Rendering.View>(_ v: V, _ ctx: inout C) {
        V._render(v, context: &ctx)
    }
    repeat render(each view.content, &context)  // SEQUENTIAL (flat, not recursive)
}
```

**`HTML.AnyView`** (type-erased wrapper):
```swift
public static func _render<C>(_ view: borrowing HTML.AnyView, context: inout C) {
    _openAndRender(view.base, context: &context)
}
private static func _openAndRender<V: HTML.View, C: Rendering.Context>(
    _ base: V, context: inout C
) {
    V._render(base, context: &context)  // OPENS EXISTENTIAL + RECURSIVE CALL
}
```

**`HTML.Element.Tag`** (leaf elements):
```swift
// Calls push.element(), renders content, calls pop.element()
public static func _render<C: Rendering.Context>(
    _ view: borrowing Self, context: inout C
) {
    context.push.element(
        tagName: view.tagName,
        block: view.isBlock,
        void: view.isVoid,
        preformatted: view.isPreElement
    )
    if let content = view.content {
        Content._render(content, context: &context)  // RECURSIVE into content
    }
    context.pop.element(block: view.isBlock)
}
```

**`HTML.Styled`** (CSS property wrapper):
```swift
// Pushes style scope, applies property, renders content, pops style
public static func _render<C: Rendering.Context>(
    _ view: borrowing Self, context: inout C
) {
    context.push.style()
    if context.apply(inlineStyle: view.property) {
        // PDF handled it
    } else {
        // HTML: register as CSS class
        context.register(style: ...)
    }
    Content._render(view.content, context: &context)  // RECURSIVE into content
    context.pop.style()
}
```

### 6.2 Stack Frame Accumulation

Each level in the view tree adds AT LEAST one `_render<C>` call frame. For views
with `body` properties, there are typically 2 frames (the _render call + property
access for body). For `AnyView`, there are 3 frames (_render + _openAndRender +
existential thunk).

The `PDF.HTML.Context._pushElement` and `_popElement` methods are substantial
(100+ lines with switch statements, margin collapsing, heading tracking, table
management). Each pushElement/popElement pair on the call stack holds significant
local state.

---

## 7. Hypotheses to Investigate

### 7.1 Hypothesis A: Static Dispatch Recursion Depth

The pure static dispatch path (`_render → body → _render → body → ...`) may
accumulate enough frames to overflow the ~64KB async task stack. Each CSS wrapper
(`.css.display(.block)`, `.css.inlineStyle(...)`) adds a `Styled<Content>._render`
frame. The markdown converter wraps content in multiple layers.

**Investigation approach**:
1. Add `Thread.callStackSymbols.count` or `pthread_get_stackaddr_np` instrumentation
   to `PDF.HTML.Context._pushElement` to measure actual stack depth at crash point
2. Run with increased stack size: `SWIFT_TESTING_STACK_SIZE=1048576 swift test`
   (if supported) or use `Thread(stackSize:)` wrapper
3. Count the actual number of nested `_render` frames in a crash backtrace:
   `swift test 2>&1 | head -100` or use `lldb` to capture the stack

### 7.2 Hypothesis B: `repeat` Parameter Pack Expansion

The `repeat render(each view.content, &context)` in `_Tuple._render` may generate
deeper call stacks than expected. If the Swift runtime implements parameter pack
iteration via recursive metadata walking (to determine the number of elements and
their types), a 10-element tuple could add 10+ frames to the stack.

**Investigation approach**:
1. Create a minimal test with a flat `_Tuple` of 50 `HTML.Text` elements and render
   to `PDF.HTML.Context`. Does it crash?
2. Compare with rendering the same 50 elements via `Array<HTML.AnyView>` (which uses
   `for`-loop iteration, not parameter pack expansion)
3. Check SIL output: `swiftc -emit-sil` for a `repeat` expansion to see if the
   compiler generates recursive vs iterative code

### 7.3 Hypothesis C: AnyView Existential Opening Overhead

`HTML.AnyView._openAndRender` uses existential opening (`func render<V: HTML.View>`)
which may add unexpected stack overhead per type. The markdown converter wraps EVERY
node in `AnyView`, so every element goes through existential opening twice (once for
`AnyView._render`, once for `_openAndRender`).

**Investigation approach**:
1. Count the total number of `AnyView` instances in a typical markdown document
2. Measure the stack frame size of `_openAndRender` (it's a generic function that
   the compiler may not inline in debug builds)
3. Test if removing the `AnyView` layer (using concrete types) eliminates the crash

### 7.4 Hypothesis D: PDF.HTML.Context._pushElement Frame Size

`_pushElement` in `PDF.HTML.Context+Rendering.swift` (lines 314–448) is a large
function with:
- `Element.Scope` construction (13 fields)
- `applyTagStyle` call (large switch statement)
- `blockMargins` computation (CSS length → PDF conversion)
- `pushBlockElement` call (another large switch for table/list handling)

Each of these sub-calls may contribute significant stack usage. The `Element.Scope`
struct alone has 11 stored properties including `PDF.Context.Style` (which contains
font, fontSize, color, lineHeight, textMarkup, verticalOffset, textAlign).

**Investigation approach**:
1. Measure `sizeof(Element.Scope)` and `sizeof(PDF.Context.Style)`
2. Check if `_pushElement` is marked `@inline(never)` or if it gets inlined (which
   would compound its frame size into the caller)
3. Add `@inline(never)` to `_pushElement` and `_popElement` to isolate their stack
   contribution

### 7.5 Hypothesis E: Swift Testing Async Task Stack Size

Swift Testing runs each `@Test` function as an async task. The default async task
stack size is ~64KB on Darwin. This is NOT configurable through Swift Testing's API.

**Investigation approach**:
1. Wrap the test body in `Thread.detachNewThread(stackSize: 1_048_576) { ... }` or
   `Task(stackSize: ...)` if available, and see if the crash disappears
2. Run the same rendering code from a synchronous main function (which gets the
   main thread's 8MB stack) and confirm it succeeds
3. Check `SWIFT_TESTING_STACK_SIZE` or `SWIFT_TASK_DEFAULT_STACK_SIZE` environment
   variables

---

## 8. The Crashing Tests

```swift
// File: swift-pdf/Tests/PDF Tests/PDF Tests.swift

extension PDF.Test.Unit {
    @Suite("Markdown to PDF Tests")
    struct MarkdownToPDF {

        @Test
        func `Basic markdown renders to PDF`() throws {
            let doc = PDF.Document(
                info: .init(title: "Markdown Demo", author: "Test Suite"),
                generateOutline: true
            ) {
                Markdown.HTML {
                    """
                    # Welcome to Markdown PDF

                    This document demonstrates **Markdown to PDF** rendering.

                    ## Features

                    - Bold and *italic* text
                    - Lists (ordered and unordered)
                    - Code blocks
                    - And much more!

                    ### Code Example

                    Here's some inline `code` and a code block:

                    ```swift
                    let greeting = "Hello, World!"
                    print(greeting)
                    ```

                    ## Conclusion

                    Markdown makes document creation simple and readable.
                    """
                }
            }
            try doc.write(
                to: File("/tmp/swift-pdf/markdown-to-pdf-test.pdf"),
                options: .init(createIntermediates: true)
            )
            #expect(doc.pages.count >= 1)
            #expect(doc.outline != nil)
        }

        @Test
        func `Markdown with tables renders to PDF`() throws {
            let markdown = Markdown.HTML()
            let doc = PDF.Document(
                info: .init(title: "Markdown Table Demo", author: "Test Suite")
            ) {
                markdown {
                    """
                    # Product Catalog

                    Here's our current inventory:

                    | Product | Price | Stock |
                    |---------|-------|-------|
                    | Widget A | $10.00 | 100 |
                    | Widget B | $15.00 | 50 |
                    | Widget C | $20.00 | 25 |

                    ## Notes

                    - Prices subject to change
                    - Stock updated daily
                    """
                }
            }
            #expect(doc.pages.count >= 1)
            try doc.write(
                to: File("/tmp/swift-pdf/markdown-table-to-pdf-test.pdf"),
                options: .init(createIntermediates: true)
            )
        }

        @Test
        func `Complex markdown document renders to PDF`() throws {
            // Long markdown with headings, code blocks, ordered lists, table, link
            // ... (see full content in PDF Tests.swift)
            let doc = PDF.Document(
                info: .init(title: "Technical Documentation", author: "Test Suite"),
                generateOutline: true
            ) {
                Markdown.HTML { """...""" }
            }
            try doc.write(
                to: File("/tmp/swift-pdf/markdown-complex-to-pdf-test.pdf"),
                options: .init(createIntermediates: true)
            )
            #expect(doc.pages.count >= 1)
            #expect(doc.outline != nil)
        }
    }
}
```

Note: even the SIMPLEST test ("Basic markdown") crashes. It has only:
- 3 headings (h1, h2, h3)
- 2 paragraphs
- 1 unordered list (4 items)
- 1 code block

This suggests the issue is NOT about document size but about the depth of the
rendering stack per element.

---

## 9. What Works (for comparison)

These tests in the NESTED package (`Tests/Package.swift`) all pass:

```swift
// File: swift-pdf-html-rendering/Tests/PDF HTML Rendering Tests/IterativeTupleTests.swift

// 10x10 table (100+ elements) — PASSES
// 10x30 table (300+ elements) — PASSES
// 50-element flat view hierarchy — PASSES
```

These use direct `HTML.View` construction (concrete types via `@HTML.Builder`), NOT
`HTML.AnyView` from the markdown converter. They run from the nested testing package
which uses `swift-testing` (not Apple Testing from the toolchain).

The difference:
- **Crashing path**: `Markdown.HTML { "..." }` → `HTMLConverter` → `AnyView(Array<AnyView>)` → recursive `_render`
- **Working path**: Direct `@HTML.Builder` → `_Tuple<Tag, Tag, Tag, ...>` → flat `repeat` iteration

---

## 10. Principled Solution Space

### 10.1 Option A: Increase Stack Size (Workaround, NOT principled)

Set `SWIFT_TASK_DEFAULT_STACK_SIZE=1048576` or wrap tests in a detached thread with
a larger stack. This papers over the problem without fixing the root cause.

**Not recommended**: The same issue would affect production use of markdown→PDF
rendering in async contexts.

### 10.2 Option B: Eliminate AnyView from HTMLConverter

Refactor `HTMLConverter` to produce concrete types instead of `HTML.AnyView`. This
would require the visitor to return generic `some HTML.View` from each method (which
it already does via the result builder). The question is whether `SwiftMarkdown.MarkupVisitor`
allows heterogeneous return types.

**Challenge**: The `MarkupVisitor` protocol requires a single `Result` associated type.
All visit methods must return the same type. `HTML.AnyView` is the type erasure that
enables this. Eliminating it would require a different visitor architecture.

### 10.3 Option C: Make AnyView._render Iterative (Trampoline)

When `AnyView._openAndRender` opens the existential and finds another composite view,
instead of recursing into `V._render(base, context:)`, it could check if the view
has a `body` and "bounce" — returning the body to an outer loop that re-dispatches.

This is a trampoline pattern:

```swift
// Pseudocode — the idea, not the implementation
static func _render<C>(_ view: AnyView, context: inout C) {
    var current: any HTML.View = view.base
    while true {
        // Open existential
        let result = openAndCheck(current)
        switch result {
        case .leaf(let render):
            render(&context)
            return
        case .composite(let body):
            current = body  // bounce — no recursive frame
        }
    }
}
```

**Challenge**: `Rendering.View.Body` is an associated type that may not conform to
`HTML.View` for all paths. The existential opening + body access + re-erasure needs
careful handling.

### 10.4 Option D: Reintroduce Worklist for PDF.HTML.Context

Re-add the `Stack<Dispatch>` worklist, but this time at the `Rendering.Context` level
rather than as a separate dynamic dispatch system. `PDF.HTML.Context` could override
the default `_render` dispatch to use iterative processing.

**Challenge**: `_render` is a static protocol method on `Rendering.View`, not on
`Rendering.Context`. The context receives push/pop calls but doesn't control the
traversal. A worklist would need to be at a different level.

### 10.5 Option E: Convert HTMLConverter to Use Rendering.Context Directly

Instead of producing a view tree that gets rendered recursively, the `HTMLConverter`
could directly call `context.push.element(...)`, `context.text(...)`,
`context.pop.element(...)` as it walks the markdown AST. This eliminates the
intermediate view tree entirely.

This is the most principled solution: the markdown AST is a tree, and the rendering
context has push/pop semantics designed for tree traversal. Walking the AST and
emitting context events is O(1) stack depth (the AST walker uses SwiftMarkdown's
visitor pattern which is already iterative or bounded).

**Challenge**: This bypasses the `HTML.View` composition entirely. CSS styling from
the `Markdown.HTML.Configuration.Elements` renderers would need to be applied
differently.

### 10.6 Option F: Limit _render Depth with Continuation

Add a depth counter to the rendering context. When depth exceeds a threshold, save
a continuation (the remaining view to render) and return. An outer loop picks up
continuations and processes them iteratively.

---

## 11. Investigation Checklist

### Phase 1: Measure

- [ ] Get a stack trace at the crash point (use `lldb` or `SWIFT_BACKTRACE=enable=yes`)
- [ ] Count the number of `_render` frames in the stack trace
- [ ] Measure the actual stack frame sizes of key functions:
  - `_Tuple._render` (parameter pack expansion)
  - `AnyView._render` + `_openAndRender` (existential opening)
  - `PDF.HTML.Context._pushElement` (large function)
  - `HTML.Element.Tag._render` (element rendering)
- [ ] Test with increased stack size to confirm the root cause is stack exhaustion
- [ ] Test the simplest crashing case ("Basic markdown") to find minimum reproduction

### Phase 2: Isolate

- [ ] Does the crash happen with HTML.Context (byte output) or only PDF.HTML.Context?
- [ ] Does the crash happen with a single `Paragraph { "hello" }` inside AnyView?
- [ ] Does the crash happen without CSS wrappers (no `.css.display(...)` etc.)?
- [ ] Does replacing `AnyView` with concrete types in a minimal case fix it?
- [ ] Does the `repeat` expansion in `_Tuple._render` contribute significant depth?

### Phase 3: Fix

- [ ] Choose and implement the principled fix from Section 10
- [ ] Verify all 3 markdown tests pass
- [ ] Verify the 32 nested package tests still pass
- [ ] Verify the fix works in async contexts (Task with default stack)
- [ ] Document the fix in the research document

---

## 12. Environment

| Property | Value |
|----------|-------|
| Platform | macOS (Darwin 25.2.0), arm64e |
| Swift toolchain | 6.2 |
| Build mode | Debug (no inlining, larger stack frames) |
| Test framework | Apple Testing (toolchain) — NOT swift-testing |
| Async task stack | ~64KB (Darwin default) |
| Crash signal | SIGBUS (signal 10) / `___chkstk_darwin` |

---

## 13. Key Constraints

1. The fix must work with the ~64KB async task stack — increasing stack size is not
   a valid solution for production code
2. The `Rendering.Context` protocol-based architecture must be preserved — this was
   a deliberate design choice to enable format-independent rendering
3. `HTML.AnyView` may need to exist for the `MarkupVisitor` pattern, but its rendering
   path can be redesigned
4. The fix should benefit ALL `Rendering.Context` implementations, not just PDF
5. Follow all Swift Institute conventions (see CLAUDE.md): [API-NAME-001], [API-NAME-002],
   [IMPL-INTENT], [API-IMPL-005], typed throws, etc.

---

## 14. Cross-References

| Document | Location | Purpose |
|----------|----------|---------|
| Worklist research | `swift-institute/Research/worklist-rendering-dispatch.md` | Prior fix (superseded) |
| Project memory | `swift-foundations/swift-pdf-html-rendering/Research/iterative-tuple-rendering.md` | Three-cause analysis |
| IterativeTupleTests | `swift-pdf-html-rendering/Tests/.../IterativeTupleTests.swift` | Working non-AnyView tests |
| PDF Tests | `swift-pdf/Tests/PDF Tests/PDF Tests.swift` | Crashing markdown tests |
| Rendering.View | `swift-rendering-primitives/.../Rendering.View.swift` | Core protocol |
| Rendering.Context | `swift-rendering-primitives/.../Rendering.Context.swift` | Context protocol |
| Rendering.Builder | `swift-rendering-primitives/.../Rendering.Builder.swift` | Result builder |
| Rendering._Tuple | `swift-rendering-primitives/.../Rendering._Tuple.swift` | Flat variadic tuple |
| HTML.AnyView | `swift-html-rendering/.../HTML.AnyView.swift` | Type erasure |
| PDF.HTML.Context+Rendering | `swift-pdf-html-rendering/.../PDF.HTML.Context+Rendering.swift` | PDF rendering (1095 lines) |
| HTMLConverter | `swift-markdown-html-rendering/.../HTMLConverter.swift` | Markdown → AnyView |
| Markdown.HTML | `swift-markdown-html-rendering/.../Markdown.HTML.swift` | Entry point |
