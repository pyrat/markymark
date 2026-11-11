import XCTest
import WebKit
@testable import MarkyMark

final class RenderingTests: XCTestCase {
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
