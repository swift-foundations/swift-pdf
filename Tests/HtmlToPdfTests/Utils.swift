//
//  File.swift
//
//
//  Created by Coen ten Thije Boonkkamp on 15/07/2024.
//

import Foundation
import HtmlToPdf
import Testing

extension URL {

    static func output(id: UUID = UUID()) -> Self {
        FileManager.default.temporaryDirectory.appendingPathComponent("html-to-pdf").appendingPathComponent(id.uuidString)
    }

    static var localHtmlToPdf: Self {
        #if os(macOS)
        return URL.documentsDirectory.appendingPathComponent("HtmlToPdf")
        #endif
        #if os(iOS)
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths.first!.appendingPathComponent("HtmlToPdf")
        #endif
    }
}

extension FileManager {
    func removeItems(at url: URL) throws {
        let fileURLs = try contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
        for fileURL in fileURLs {
            try removeItem(at: fileURL)
        }
    }
}

extension AsyncStream<URL> {
    func testIfYieldedUrlExistsOnFileSystem(directory: URL) async throws {
        for await url in self {
            let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                .map(\.lastPathComponent)
            #expect(contents.contains(where: { $0 == url.lastPathComponent }))
        }
    }
}

extension AsyncThrowingStream<URL, Error> {
    func testIfYieldedUrlExistsOnFileSystem(directory: URL) async throws {
        for try await url in self {
            let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                .map(\.lastPathComponent)
            #expect(contents.contains(where: { $0 == url.lastPathComponent }))
        }
    }
}

extension String {
    static let html = """
    <html>
        <body>
            <h1>Hello, World! Hello, World! Hello, World! Hello, World! Hello, World! Hello, World! Hello, World! Hello, World!</h1>
        </body>
    </html>
    """

    static let html2 = """
    <html>
        <body>
            <h1>Hello, World!</h1>
            <h2>Hello, World! subheader</h2>
            <p>Sed euismod, nunc vel mollis interdum, mi nulla vehicula urna, a gravida tellus ante nec velit. Nunc sed lectus vehicula, pulvinar ante a, hendrerit arcu. Nulla turpis urna, luctus at sagittis non, dignissim vitae ligula. Nam nec venenatis enim. Aenean ut nibh id erat faucibus tincidunt. Etiam eu magna ac purus consequat dignissim vel ac ipsum. Maecenas at luctus odio. Maecenas facilisis eleifend tempor. Quisque mi lorem, aliquam vitae vulputate faucibus, pharetra id mauris. Proin molestie lacus sit amet faucibus dapibus. Sed nibh dui, vehicula sed leo ut, blandit tempus ipsum. Nullam bibendum molestie dapibus. In hac habitasse platea dictumst.</p>
            <p>Aenean vulputate nulla dolor, vitae tempor felis egestas ut. Praesent faucibus sagittis dictum. Nam scelerisque lacinia accumsan. Nam ultricies urna sit amet vulputate faucibus. Proin iaculis magna et augue sagittis, a posuere lacus rutrum. Sed faucibus nulla a libero ultricies fermentum. Pellentesque malesuada sem pulvinar rutrum efficitur. Vivamus mattis condimentum nulla, id consequat arcu tincidunt at. Nunc pharetra molestie purus, ut blandit velit semper a. Integer scelerisque, ipsum et accumsan condimentum, nibh nulla viverra elit, at suscipit quam mauris et massa. Maecenas tempor urna efficitur diam molestie, vitae eleifend tellus aliquam. Phasellus eros ex, rutrum quis felis vel, egestas condimentum ligula. Donec a arcu eget lacus laoreet pharetra.</p>
            <p>Praesent id lorem eleifend risus vestibulum tristique. Donec tristique pretium arcu et finibus. Fusce eget tellus pretium, pellentesque neque facilisis, fringilla augue. Praesent bibendum, purus dictum posuere interdum, enim sapien elementum augue, consectetur porta tellus nulla at dui. Etiam nec elit a ligula iaculis ultrices. Phasellus vulputate varius turpis, quis interdum tortor posuere id. Proin eu lorem sagittis, aliquet nisi ut, blandit ligula. Vestibulum vel ultrices magna. In est sapien, ultricies in mauris et, egestas laoreet orci. Praesent ornare ante sollicitudin pretium consectetur. Sed nec nisi enim. Vestibulum sodales est eu vestibulum venenatis.</p>
            <p>Nulla sagittis augue vel purus posuere egestas. Donec lacinia metus sit amet nulla tincidunt, eu consequat mi facilisis. Suspendisse mollis magna ut mauris interdum tincidunt. Vivamus non justo nec elit hendrerit maximus. Maecenas sollicitudin tincidunt mauris. Praesent quis velit quis justo pharetra rhoncus a et metus. Donec nec luctus libero. Cras sapien ipsum, pharetra id massa sed, rhoncus sagittis erat. Nam eu urna eget massa commodo tempor tincidunt nec velit. Duis bibendum cursus magna, nec iaculis turpis dapibus fringilla. Pellentesque et suscipit dolor. Praesent ac lectus quis dolor vestibulum lobortis vitae vestibulum leo. In at risus ut urna convallis dignissim. Proin vel magna vulputate, posuere augue at, ornare sapien.</p>
            <p>Sed euismod, nunc vel mollis interdum, mi nulla vehicula urna, a gravida tellus ante nec velit. Nunc sed lectus vehicula, pulvinar ante a, hendrerit arcu. Nulla turpis urna, luctus at sagittis non, dignissim vitae ligula. Nam nec venenatis enim. Aenean ut nibh id erat faucibus tincidunt. Etiam eu magna ac purus consequat dignissim vel ac ipsum. Maecenas at luctus odio. Maecenas facilisis eleifend tempor. Quisque mi lorem, aliquam vitae vulputate faucibus, pharetra id mauris. Proin molestie lacus sit amet faucibus dapibus. Sed nibh dui, vehicula sed leo ut, blandit tempus ipsum. Nullam bibendum molestie dapibus. In hac habitasse platea dictumst.</p>
            <p>Aenean vulputate nulla dolor, vitae tempor felis egestas ut. Praesent faucibus sagittis dictum. Nam scelerisque lacinia accumsan. Nam ultricies urna sit amet vulputate faucibus. Proin iaculis magna et augue sagittis, a posuere lacus rutrum. Sed faucibus nulla a libero ultricies fermentum. Pellentesque malesuada sem pulvinar rutrum efficitur. Vivamus mattis condimentum nulla, id consequat arcu tincidunt at. Nunc pharetra molestie purus, ut blandit velit semper a. Integer scelerisque, ipsum et accumsan condimentum, nibh nulla viverra elit, at suscipit quam mauris et massa. Maecenas tempor urna efficitur diam molestie, vitae eleifend tellus aliquam. Phasellus eros ex, rutrum quis felis vel, egestas condimentum ligula. Donec a arcu eget lacus laoreet pharetra.</p>
            <p>Praesent id lorem eleifend risus vestibulum tristique. Donec tristique pretium arcu et finibus. Fusce eget tellus pretium, pellentesque neque facilisis, fringilla augue. Praesent bibendum, purus dictum posuere interdum, enim sapien elementum augue, consectetur porta tellus nulla at dui. Etiam nec elit a ligula iaculis ultrices. Phasellus vulputate varius turpis, quis interdum tortor posuere id. Proin eu lorem sagittis, aliquet nisi ut, blandit ligula. Vestibulum vel ultrices magna. In est sapien, ultricies in mauris et, egestas laoreet orci. Praesent ornare ante sollicitudin pretium consectetur. Sed nec nisi enim. Vestibulum sodales est eu vestibulum venenatis.</p>
            <p>Nulla sagittis augue vel purus posuere egestas. Donec lacinia metus sit amet nulla tincidunt, eu consequat mi facilisis. Suspendisse mollis magna ut mauris interdum tincidunt. Vivamus non justo nec elit hendrerit maximus. Maecenas sollicitudin tincidunt mauris. Praesent quis velit quis justo pharetra rhoncus a et metus. Donec nec luctus libero. Cras sapien ipsum, pharetra id massa sed, rhoncus sagittis erat. Nam eu urna eget massa commodo tempor tincidunt nec velit. Duis bibendum cursus magna, nec iaculis turpis dapibus fringilla. Pellentesque et suscipit dolor. Praesent ac lectus quis dolor vestibulum lobortis vitae vestibulum leo. In at risus ut urna convallis dignissim. Proin vel magna vulputate, posuere augue at, ornare sapien.</p>
            <p>Sed euismod, nunc vel mollis interdum, mi nulla vehicula urna, a gravida tellus ante nec velit. Nunc sed lectus vehicula, pulvinar ante a, hendrerit arcu. Nulla turpis urna, luctus at sagittis non, dignissim vitae ligula. Nam nec venenatis enim. Aenean ut nibh id erat faucibus tincidunt. Etiam eu magna ac purus consequat dignissim vel ac ipsum. Maecenas at luctus odio. Maecenas facilisis eleifend tempor. Quisque mi lorem, aliquam vitae vulputate faucibus, pharetra id mauris. Proin molestie lacus sit amet faucibus dapibus. Sed nibh dui, vehicula sed leo ut, blandit tempus ipsum. Nullam bibendum molestie dapibus. In hac habitasse platea dictumst.</p>
            <p>Aenean vulputate nulla dolor, vitae tempor felis egestas ut. Praesent faucibus sagittis dictum. Nam scelerisque lacinia accumsan. Nam ultricies urna sit amet vulputate faucibus. Proin iaculis magna et augue sagittis, a posuere lacus rutrum. Sed faucibus nulla a libero ultricies fermentum. Pellentesque malesuada sem pulvinar rutrum efficitur. Vivamus mattis condimentum nulla, id consequat arcu tincidunt at. Nunc pharetra molestie purus, ut blandit velit semper a. Integer scelerisque, ipsum et accumsan condimentum, nibh nulla viverra elit, at suscipit quam mauris et massa. Maecenas tempor urna efficitur diam molestie, vitae eleifend tellus aliquam. Phasellus eros ex, rutrum quis felis vel, egestas condimentum ligula. Donec a arcu eget lacus laoreet pharetra.</p>
            <p>Praesent id lorem eleifend risus vestibulum tristique. Donec tristique pretium arcu et finibus. Fusce eget tellus pretium, pellentesque neque facilisis, fringilla augue. Praesent bibendum, purus dictum posuere interdum, enim sapien elementum augue, consectetur porta tellus nulla at dui. Etiam nec elit a ligula iaculis ultrices. Phasellus vulputate varius turpis, quis interdum tortor posuere id. Proin eu lorem sagittis, aliquet nisi ut, blandit ligula. Vestibulum vel ultrices magna. In est sapien, ultricies in mauris et, egestas laoreet orci. Praesent ornare ante sollicitudin pretium consectetur. Sed nec nisi enim. Vestibulum sodales est eu vestibulum venenatis.</p>
            <p>Nulla sagittis augue vel purus posuere egestas. Donec lacinia metus sit amet nulla tincidunt, eu consequat mi facilisis. Suspendisse mollis magna ut mauris interdum tincidunt. Vivamus non justo nec elit hendrerit maximus. Maecenas sollicitudin tincidunt mauris. Praesent quis velit quis justo pharetra rhoncus a et metus. Donec nec luctus libero. Cras sapien ipsum, pharetra id massa sed, rhoncus sagittis erat. Nam eu urna eget massa commodo tempor tincidunt nec velit. Duis bibendum cursus magna, nec iaculis turpis dapibus fringilla. Pellentesque et suscipit dolor. Praesent ac lectus quis dolor vestibulum lobortis vitae vestibulum leo. In at risus ut urna convallis dignissim. Proin vel magna vulputate, posuere augue at, ornare sapien.</p>
            <p>Sed euismod, nunc vel mollis interdum, mi nulla vehicula urna, a gravida tellus ante nec velit. Nunc sed lectus vehicula, pulvinar ante a, hendrerit arcu. Nulla turpis urna, luctus at sagittis non, dignissim vitae ligula. Nam nec venenatis enim. Aenean ut nibh id erat faucibus tincidunt. Etiam eu magna ac purus consequat dignissim vel ac ipsum. Maecenas at luctus odio. Maecenas facilisis eleifend tempor. Quisque mi lorem, aliquam vitae vulputate faucibus, pharetra id mauris. Proin molestie lacus sit amet faucibus dapibus. Sed nibh dui, vehicula sed leo ut, blandit tempus ipsum. Nullam bibendum molestie dapibus. In hac habitasse platea dictumst.</p>
            <p>Aenean vulputate nulla dolor, vitae tempor felis egestas ut. Praesent faucibus sagittis dictum. Nam scelerisque lacinia accumsan. Nam ultricies urna sit amet vulputate faucibus. Proin iaculis magna et augue sagittis, a posuere lacus rutrum. Sed faucibus nulla a libero ultricies fermentum. Pellentesque malesuada sem pulvinar rutrum efficitur. Vivamus mattis condimentum nulla, id consequat arcu tincidunt at. Nunc pharetra molestie purus, ut blandit velit semper a. Integer scelerisque, ipsum et accumsan condimentum, nibh nulla viverra elit, at suscipit quam mauris et massa. Maecenas tempor urna efficitur diam molestie, vitae eleifend tellus aliquam. Phasellus eros ex, rutrum quis felis vel, egestas condimentum ligula. Donec a arcu eget lacus laoreet pharetra.</p>
            <p>Praesent id lorem eleifend risus vestibulum tristique. Donec tristique pretium arcu et finibus. Fusce eget tellus pretium, pellentesque neque facilisis, fringilla augue. Praesent bibendum, purus dictum posuere interdum, enim sapien elementum augue, consectetur porta tellus nulla at dui. Etiam nec elit a ligula iaculis ultrices. Phasellus vulputate varius turpis, quis interdum tortor posuere id. Proin eu lorem sagittis, aliquet nisi ut, blandit ligula. Vestibulum vel ultrices magna. In est sapien, ultricies in mauris et, egestas laoreet orci. Praesent ornare ante sollicitudin pretium consectetur. Sed nec nisi enim. Vestibulum sodales est eu vestibulum venenatis.</p>
            <p>Nulla sagittis augue vel purus posuere egestas. Donec lacinia metus sit amet nulla tincidunt, eu consequat mi facilisis. Suspendisse mollis magna ut mauris interdum tincidunt. Vivamus non justo nec elit hendrerit maximus. Maecenas sollicitudin tincidunt mauris. Praesent quis velit quis justo pharetra rhoncus a et metus. Donec nec luctus libero. Cras sapien ipsum, pharetra id massa sed, rhoncus sagittis erat. Nam eu urna eget massa commodo tempor tincidunt nec velit. Duis bibendum cursus magna, nec iaculis turpis dapibus fringilla. Pellentesque et suscipit dolor. Praesent ac lectus quis dolor vestibulum lobortis vitae vestibulum leo. In at risus ut urna convallis dignissim. Proin vel magna vulputate, posuere augue at, ornare sapien.</p>
            <p>Sed euismod, nunc vel mollis interdum, mi nulla vehicula urna, a gravida tellus ante nec velit. Nunc sed lectus vehicula, pulvinar ante a, hendrerit arcu. Nulla turpis urna, luctus at sagittis non, dignissim vitae ligula. Nam nec venenatis enim. Aenean ut nibh id erat faucibus tincidunt. Etiam eu magna ac purus consequat dignissim vel ac ipsum. Maecenas at luctus odio. Maecenas facilisis eleifend tempor. Quisque mi lorem, aliquam vitae vulputate faucibus, pharetra id mauris. Proin molestie lacus sit amet faucibus dapibus. Sed nibh dui, vehicula sed leo ut, blandit tempus ipsum. Nullam bibendum molestie dapibus. In hac habitasse platea dictumst.</p>
            <p>Aenean vulputate nulla dolor, vitae tempor felis egestas ut. Praesent faucibus sagittis dictum. Nam scelerisque lacinia accumsan. Nam ultricies urna sit amet vulputate faucibus. Proin iaculis magna et augue sagittis, a posuere lacus rutrum. Sed faucibus nulla a libero ultricies fermentum. Pellentesque malesuada sem pulvinar rutrum efficitur. Vivamus mattis condimentum nulla, id consequat arcu tincidunt at. Nunc pharetra molestie purus, ut blandit velit semper a. Integer scelerisque, ipsum et accumsan condimentum, nibh nulla viverra elit, at suscipit quam mauris et massa. Maecenas tempor urna efficitur diam molestie, vitae eleifend tellus aliquam. Phasellus eros ex, rutrum quis felis vel, egestas condimentum ligula. Donec a arcu eget lacus laoreet pharetra.</p>
        </body>
    </html>
    """

}



