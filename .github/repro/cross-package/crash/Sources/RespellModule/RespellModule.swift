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
            let unwrapped: Any
            let mirror = Mirror(reflecting: property)
            if mirror.displayStyle == .optional {
                guard let first = mirror.children.first else { return false }
                unwrapped = first.value
            } else {
                unwrapped = property
            }

            var handled = false

            if let modifier = unwrapped as? any ISO_32000.HTML.Style.Modifier {
                modifier.apply(to: &pdf, configuration: configuration)
                handled = true
            }

            if let htmlModifier = unwrapped as? any ISO_32000.HTML.Style.Context.Modifier {
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
