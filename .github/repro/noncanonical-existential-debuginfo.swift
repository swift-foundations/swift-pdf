// Minimal reproducer — Swift 6.3.3 Windows (+Asserts) debug-info-mangler ICE
// on a plain nested-namespace protocol existential.
//
// Classification: ICE (assertion) during IRGen debug-info type mangling.
// Environment:    Windows (windows-msvc), Swift 6.3.3 (+Asserts), -Onone -g.
//                 macOS toolchains are non-asserts; the assertion cannot fire there.
// Command:        swiftc -Onone -g -c noncanonical-existential-debuginfo.swift -o repro.o
// Observed:       Assertion failed: isActuallyCanonicalOrNull() &&
//                 "Forming a CanType out of a non-canonical type!", AST/Type.h:421
//                 while mangling debugger type 'any PDF.HTML.Style.Modifier'.
// Expected:       Clean compile.
//
// Shape mirrored from swift-pdf-html-render's PDF.HTML.Context.apply(inlineStyle:)
// (PDF.HTML.Context+Rendering.swift:267/:283): SE-0404 protocols nested in a
// three-level enum namespace, an `Any` value unwrapped via Mirror, then explicit
// `as? any …Modifier` downcasts whose local bindings receive debug info. The
// protocols are PLAIN — no ~Copyable, no recursion, no associated types.
//
// TRACKING: swift-institute/Issues — swift-issue-noncanonical-existential-windows-debuginfo-ice

public enum PDF {
    public enum HTML {
        public enum Style {
            public enum Context {}
        }
    }
}

extension PDF {
    public struct Context {
        public var value: Int = 0
        public init() {}
    }
}

extension PDF.HTML {
    public struct Configuration {
        public init() {}
    }
}

extension PDF.HTML.Style {
    public protocol Modifier {
        func apply(to context: inout PDF.Context, configuration: PDF.HTML.Configuration)
    }
}

extension PDF.HTML.Style.Context {
    public protocol Modifier {
        func apply(to context: inout PDF.HTML.Context)
    }
}

extension PDF.HTML {
    public struct Context {
        public var pdf = PDF.Context()
        public var configuration = PDF.HTML.Configuration()
        public init() {}

        public mutating func apply(inlineStyle property: Any) -> Bool {
            // Unwrap Optional if needed (mirrors the production dataflow).
            let unwrapped: Any
            let mirror = Mirror(reflecting: property)
            if mirror.displayStyle == .optional {
                guard let first = mirror.children.first else { return false }
                unwrapped = first.value
            } else {
                unwrapped = property
            }

            var handled = false

            if let modifier = unwrapped as? any PDF.HTML.Style.Modifier {
                modifier.apply(to: &pdf, configuration: configuration)
                handled = true
            }

            if let htmlModifier = unwrapped as? any PDF.HTML.Style.Context.Modifier {
                htmlModifier.apply(to: &self)
                handled = true
            }

            return handled
        }
    }
}

public struct Bold: PDF.HTML.Style.Modifier {
    public init() {}
    public func apply(to context: inout PDF.Context, configuration: PDF.HTML.Configuration) {
        context.value += 1
    }
}

public struct PageBreak: PDF.HTML.Style.Context.Modifier {
    public init() {}
    public func apply(to context: inout PDF.HTML.Context) {
        context.pdf.value += 1
    }
}

var context = PDF.HTML.Context()
let boldHandled = context.apply(inlineStyle: Bold())
let pageBreakHandled = context.apply(inlineStyle: Optional.some(PageBreak()) as Any)
print(boldHandled, pageBreakHandled, context.pdf.value)
