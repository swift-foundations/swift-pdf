# swift-html-to-pdf Excellence Audit: Questionnaire

This questionnaire will help identify areas for refinement to make this project a prime showcase of API design, domain modeling, and performance engineering.

## Part 1: Project Vision & Goals

### 1.1 Primary Audience
- **Q**: Who is the primary audience for this library? (e.g., Swift server developers, iOS/macOS app developers, enterprise teams, open-source community)
currently iOS/macOS app developers. but I want to use it on the server in the future (obviously with a different renefring engine as current is apple platforms only)
- **Q**: What level of Swift expertise do you expect users to have? (beginner, intermediate, advanced)
I want it to be extremely beginner friendly, with progressive disclosure, and advanced configuration possible. 
- **Q**: Should the API optimize for discoverability, explicitness, or terseness?
I want it to be extremely beginner friendly, with progressive disclosure, and advanced configuration possible. Implementation should be ROCK solid and performant, with easy to use APIs, with progressive discolsure. 

### 1.2 Core Use Cases
- **Q**: What are the top 3 use cases you want to excel at? (e.g., single PDF generation, batch processing, real-time generation, invoice generation, report generation)
I want to generate general business documents from HTML to PDF. like invoices, contracts, etc.
- **Q**: Which use case should require the least configuration/code?
printing HTML whether as Data or String should be least configurable, with multiple pdfs not much more complex.
- **Q**: Are there any use cases the library should explicitly NOT support?

### 1.3 Design Philosophy
- **Q**: On a scale from "batteries-included" to "minimal & composable", where should this library sit?
minimal and composable, but configurable.
- **Q**: How should the library handle trade-offs between performance and developer experience?
no trade-offs ideally. 
- **Q**: Should the API favor compile-time safety or runtime flexibility?
compile time safety at all times.

## Part 2: API Design Review

### 2.1 Public API Surface
- **Q**: Looking at the public API, what should be the "happy path" for generating a single PDF? Can you write the ideal code example?
@Dependency(\.pdf) var pdf
pdf.render(html)
- **Q**: What should batch processing look like? Should it feel different from single generation?
as similar as possible, should be invisible to the end user, except return type (URL vs stream)
- **Q**: Are there any APIs you find yourself explaining frequently? (candidates for redesign)


### 2.2 Configuration Strategy
- **Q**: Is the current configuration approach (dependency injection via `withDependencies` or trait-based) the right level of abstraction?
use traits where possible, then withdependencies if necessary or actually appropriate. 
- **Q**: Should configuration be more hierarchical? (e.g., global defaults → operation-specific overrides)
this is already the case I believe.
- **Q**: Are there configuration options that should be split or combined?
Please advise on this

### 2.3 Error Handling
- **Q**: What should happen when PDF generation fails? Should errors be recoverable?
Please advise on this
- **Q**: In batch operations, should one failure stop the entire batch or continue with others?
Please advise on this. probaly only report and then continue
- **Q**: Should the library distinguish between user errors (bad config) vs system errors (out of memory)?
bad config should be impossible through excellent domain model

### 2.4 Async/Concurrency Model
- **Q**: Is `AsyncThrowingStream` the right abstraction for batch results, or should it offer alternatives?
you tell me. I think it is the best we got.
- **Q**: Should users have more fine-grained control over task cancellation?
please advise
- **Q**: Should there be sync APIs for simple use cases?
NO.

## Part 3: Domain Model Quality

### 3.1 Type Design
- **Q**: Looking at types like `PDF.Document`, `PDF.Configuration`, `PDF.Result` - do they represent the domain accurately?
you tell me
- **Q**: Are there any "stringly-typed" APIs that should be more type-safe?
please investigate
- **Q**: Are there missing types that would make the domain clearer? (e.g., `HTML`, `FilePath`, `PDFMetadata`)
please advise. 

### 3.2 Naming Conventions
- **Q**: Does the `PDF` namespace feel right, or should it be more specific? (e.g., `HTMLToPDF`, `PDFRenderer`)
yes. and we have subdomains like PDF.Render, which we can expand in the future, e.g. MERGE?
- **Q**: Are there any names that feel awkward or unclear? (e.g., `PDF.Render.Client`)
NO this is intentional
- **Q**: Should the library follow SwiftUI-style naming (noun for data, verb for operations)?
Please check if this is the case

### 3.3 Value Semantics
- **Q**: Should all configuration types be structs (value types) or should some be classes/actors?
all configuration types should be value types. prefer structs, enums only where absolutely perfect for that cae. in particular, no enums with 'case custom' (use strucs with static let or static var extensions to mirror API at use). enums are good where exhaustive switching is absolutely necessary.
- **Q**: Are there any reference-type semantics that would benefit the model?
prefer no reference semantics, except when absolutely critical for performance. and should be private implementation details. 

## Part 4: Performance Excellence

### 4.1 Performance Characteristics
- **Q**: What are the performance SLAs you want to commit to? (e.g., X PDFs/sec, Y latency)
state of the art ideally. 1900 pdf/sec currently for contineous is good enough. I'm not completely satisfied with paginated, which is 4/5x slower. 
- **Q**: Should the library optimize for throughput (batch) or latency (single PDF)?
good balance between quick job for single pdf and throughput for large. Ideally with no trade-offs. 
- **Q**: What should be the memory ceiling for batch operations?
Memory ceiling can remain as is (empirical testing show little memory impact).

### 4.2 Resource Management
- **Q**: Is the WebView pooling strategy clearly documented and tuneable?
I think so, see ../swift-resource-pool
- **Q**: Should there be performance presets? (e.g., `.conservative`, `.balanced`, `.aggressive`)
please advise
- **Q**: Should the library expose performance metrics? (e.g., pool utilization, average render time)
please advise

### 4.3 Benchmarking & Profiling
- **Q**: Should performance benchmarks be part of CI/CD?
please advise. do the industry standard here.
- **Q**: Should there be a performance regression detection system?
please advise. do the industry standard here.
- **Q**: What metrics should be tracked over time? (throughput, memory, latency percentiles)
please advise. do the industry standard here.

## Part 5: Documentation & Developer Experience

### 5.1 Documentation Completeness
- **Q**: What documentation currently exists? (README, API docs, examples, guides)
docc documentation should be improved, and readme updated. other scripts .md files should likely be stripped from the project
- **Q**: What documentation is missing? (migration guides, performance tuning, troubleshooting)
we're pre 1.0.0 release, so lets do necessary documents, but not more. Documents should be about how to use the package and why to use the package.
- **Q**: Should there be runnable examples in the repo?
use tests as the runnable examples.

### 5.2 Error Messages & Debugging
- **Q**: Are error messages actionable? Do they suggest fixes?
please advise based on current code. and what ideally it would look like.
- **Q**: Should there be a debug mode with verbose logging?
please advise based on current code. and what industry standard is. 
- **Q**: Should the library integrate with OSLog/swift-log?
please advise based on current code. and what industry standard is. 

### 5.3 Testing Story
- **Q**: What testing patterns should users follow when consuming this library?
dont test, the library is fully tested.
- **Q**: Should there be test helpers/fixtures in a separate target?
no
- **Q**: How should users test PDF generation without flakiness?
the tests never fail currently, so you tell me. We could have a PDFTestSupport target with test utilities.

## Part 6: Code Quality & Maintainability

### 6.1 Internal Architecture
- **Q**: Looking at the implementation, are there areas with high cyclomatic complexity?
you tell me
- **Q**: Are responsibilities clearly separated? (rendering, pooling, configuration, etc.)
you tell me
- **Q**: Should any internal types become public for advanced use cases?
probably not.

### 6.2 Dependencies
- **Q**: Is the dependency on `swift-dependencies` appropriate, or should it be optional?
keep it
- **Q**: Are there transitive dependencies that should be eliminated?
please identify if any
- **Q**: Should the library offer different "flavors" with/without dependencies?
no.

### 6.3 Platform Support
- **Q**: What is the minimum deployment target? Should older versions be supported?
ideally we'd support as low as we can, but we don't want to sacrifice modern swift features like concurrency. If it turns out we must use 6.2 only for example, so be it.
- **Q**: Should Linux support be first-class or best-effort?
not yet, but foundation sohuld be laid for future support
- **Q**: Are platform-specific implementations clearly separated?
I think so

## Part 7: Showcase-Specific Questions

### 7.1 What Makes This Special?
- **Q**: What is the "wow factor" that makes this library stand out?
you tell me
- **Q**: What unique technical challenges did you solve?
you tell me
- **Q**: What patterns/techniques here should be emulated in other projects?
I generally like how we've structuerd it so far, with the domain first approach, layering conveneicne on top. IT's very modular and testable.

### 7.2 Portfolio Presentation
- **Q**: If you could show just ONE file to demonstrate your skills, which would it be?
you tell me
- **Q**: What metrics/achievements should be highlighted? (e.g., "Achieves 2000 PDFs/sec with <200MB memory")
performance and ease of use
- **Q**: Should there be a DESIGN.md or ARCHITECTURE.md explaining the technical decisions?
no, maybe later

### 7.3 Code Reading Experience
- **Q**: If someone unfamiliar with the codebase opens a random file, what should they immediately understand?
most types are value types, with impklementation in the clients, so that help[s. ]
- **Q**: Are there patterns that repeat across files that should be more obvious?
Dependency, Client, and 'domain model' approach.
- **Q**: Should there be more inline documentation explaining "why" vs "what"?
inline documentation should consider that this is usually used by a developer at point of use, so optimize for relevant information in that scenario. 

## Part 8: Future-Proofing

### 8.1 Extensibility
- **Q**: What are likely extension points users will need? (custom rendering, middleware, plugins)
no idea
- **Q**: Should the library use protocols for extensibility or prefer concrete types?
no protocols for now, use Client structs (closures)
- **Q**: Are there internal APIs that should be made public for power users?
I don't think so

### 8.2 API Evolution
- **Q**: What breaking changes would you consider in a 2.0?
dont know yet
- **Q**: How should deprecated APIs be communicated?
with @unavailable at firs,t then removed. but this is not yet a concern. we only do this after 1.0.0
- **Q**: Should there be a semantic versioning policy?
yes

### 8.3 Community & Maintenance
- **Q**: Will this be actively maintained? How should contributions be handled?
by me
- **Q**: Should there be CONTRIBUTING.md guidelines?
maybe later
- **Q**: What's the support model? (GitHub issues, discussions, documentation-only)
github

---

## Instructions

Please answer these questions thoughtfully. You can:
1. Answer inline with `**A**:` after each question
2. Skip questions that aren't relevant
3. Add additional concerns not covered here

Once complete, I'll generate a comprehensive audit prompt that will systematically review the codebase and propose specific improvements to achieve excellence.
