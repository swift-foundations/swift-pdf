// Mirrors swift-pdf-standard's namespace shape:
// a spec-named enum namespace re-exposed through a public typealias.
// The typealias is a load-bearing repro ingredient: the existential
// `any PDF.HTML.Style.Modifier` written through it carries TypeAliasType
// sugar at the namespace root, which is what the 6.3.3 Windows (+Asserts)
// debug-info mangler chokes on (isActuallyCanonicalOrNull, AST/Type.h:421).

public enum ISO_32000 {}

extension ISO_32000 {
    public struct Context: Sendable {
        public var value: Int
        public init() {
            self.value = 0
        }
    }
}

public typealias PDF = ISO_32000
