import XCTest
import WebKit
import PDFKit
@testable import MarkyMark

final class RenderingTests: XCTestCase {
    @MainActor
    func testPDFExportIncludesFullDocumentAndReaderStyling() async throws {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 900, height: 600))
        let loaded = expectation(description: "Export document loaded")
        let delegate = LoadDelegate { loaded.fulfill() }
        webView.navigationDelegate = delegate
        let paragraphs = (1...50).map { "Paragraph \($0) with **formatted text**." }.joined(separator: "\n\n")
        webView.loadHTMLString(Renderer.html("# Export heading\n\n" + paragraphs + "\n\nEND OF DOCUMENT"), baseURL: nil)
        await fulfillment(of: [loaded], timeout: 15)
        let contentWidth = try await webView.evaluateJavaScript("document.documentElement.clientWidth") as! Double
        _ = try await webView.evaluateJavaScript("window.scrollTo(0, 800)")
        let data = try await PDFExporter.pdfData(from: webView)
        let document = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(document.pageCount, 1)
        let page = try XCTUnwrap(document.page(at: 0))
        XCTAssertEqual(page.bounds(for: .mediaBox).width, contentWidth, accuracy: 1)
        XCTAssertGreaterThan(page.bounds(for: .mediaBox).height, 600)
        let text = try XCTUnwrap(document.string)
        XCTAssertTrue(text.contains("Export heading"))
        XCTAssertTrue(text.contains("END OF DOCUMENT"))
        // The terminal header is hidden by print CSS, so its presence verifies
        // that export uses the reader's screen layout instead.
        XCTAssertTrue(text.contains("markymark"))
        withExtendedLifetime(delegate) {}
    }

    @MainActor
    func testMarkdownRendersAndUnsafeHTMLIsRemoved() async throws {
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(LocalAssets(), forURLScheme: "markymark-local")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        let loaded = expectation(description: "Document loaded")
        let delegate = LoadDelegate { loaded.fulfill() }
        webView.navigationDelegate = delegate
        webView.loadHTMLString(Renderer.html("""
        # Hello 🌍

        **Bold** and *italic*.

        | Name | Value |
        | --- | --- |
        | Test | 42 |

        ```swift
        let greeting = "Hello"
        ```

        <script>window.compromised = true</script>
        <img src="missing.png" onerror="window.compromised = true">
        [Bad](javascript:alert(1))
        """), baseURL: nil)
        await fulfillment(of: [loaded], timeout: 15)
        let result = try await webView.evaluateJavaScript("""
        ({ pageURL: document.URL,
           imageURL: document.querySelector('img')?.src,
           heading: document.querySelector('h1')?.textContent,
           bold: document.querySelector('strong')?.textContent,
           cells: document.querySelectorAll('td').length,
           code: document.querySelector('pre code')?.textContent,
           unsafe: !!window.compromised || !!document.querySelector('#content script, [onerror], a[href^="javascript:"]') })
        """) as! [String: Any]
        XCTAssertEqual(result["pageURL"] as? String, "about:blank")
        XCTAssertEqual(result["imageURL"] as? String, "markymark-local://document/missing.png")
        XCTAssertEqual(result["heading"] as? String, "Hello 🌍")
        XCTAssertEqual(result["bold"] as? String, "Bold")
        XCTAssertEqual(result["cells"] as? Int, 2)
        XCTAssertTrue((result["code"] as? String)?.contains("let greeting") == true)
        XCTAssertEqual(result["unsafe"] as? Bool, false)
        let fontLoaded = try await webView.callAsyncJavaScript("""
        const faces = await document.fonts.load('15px "Marky Nerd"', 'Hello \\uf120');
        return faces.length > 0 && faces.every(face => face.status === 'loaded');
        """, arguments: [:], in: nil, contentWorld: .page)
        XCTAssertEqual(fontLoaded as? Bool, true, "The bundled Nerd Font should load under the page's CSP")
        withExtendedLifetime(delegate) {}
    }

    func testLocalAssetsStayWithinDocumentDirectory() {
        let assets = LocalAssets()
        assets.directory = URL(fileURLWithPath: "/Users/Shared/documents")
        XCTAssertEqual(assets.localURL(for: URL(string: "markymark-local://document/images/photo.png")!)?.path,
                       "/Users/Shared/documents/images/photo.png")
        XCTAssertNil(assets.localURL(for: URL(string: "markymark-local://document/../secret.png")!))
        XCTAssertNil(assets.localURL(for: URL(string: "markymark-local://other/photo.png")!))
    }
}

private final class LoadDelegate: NSObject, WKNavigationDelegate {
    let coordinator = MarkdownWebView.Coordinator()
    let loaded: () -> Void
    init(loaded: @escaping () -> Void) { self.loaded = loaded }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loaded() }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        coordinator.webView(webView, decidePolicyFor: navigationAction, decisionHandler: decisionHandler)
    }
}
