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
