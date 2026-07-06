// Mirrors swift-pdf-html-render's crash shape at
// PDF.HTML.Context+Rendering.swift:267/:283:
// - `PDF` below is the OTHER package's typealias for ISO_32000
//   (TypeAliasType sugar at the namespace root of every written type here);
// - `HTML`/`Style`/`Style.Context` are enums extending that sugared root;
// - `Modifier` protocols are SE-0404 nested, PLAIN (no ~Copyable, no
//   recursion, no associated types);
// - the existentials form via explicit `as? any …` downcasts from `Any`
//   whose local bindings receive debug info (-Onone -g).
//
// Expected on Windows Swift 6.3.3 (+Asserts), `swift build -c debug`:
//   Assertion failed: isActuallyCanonicalOrNull() &&
//   "Forming a CanType out of a non-canonical type!", AST/Type.h:421
//   ... While mangling type for debugger type 'any PDF.HTML.Style.Modifier'

public import BasePDF

extension PDF {
    public enum HTML {}
}

extension PDF.HTML {
    public enum Style {}

    public struct Configuration {
        public init() {}
    }
}

extension PDF.HTML.Style {
    public enum Context {}

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
        public var pdf: PDF.Context
        public var configuration: PDF.HTML.Configuration

        public init() {
            self.pdf = PDF.Context()
            self.configuration = PDF.HTML.Configuration()
        }

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

public func exercise() -> Int {
    var context = PDF.HTML.Context()
    _ = context.apply(inlineStyle: Bold())
    _ = context.apply(inlineStyle: Optional.some(PageBreak()) as Any)
    return context.pdf.value
}
