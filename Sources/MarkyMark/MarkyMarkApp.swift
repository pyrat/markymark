import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WebKit

@main
struct MarkyMarkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var viewer = ViewerModel.shared

    var body: some Scene {
        WindowGroup {
            ViewerView(viewer: viewer)
                .frame(minWidth: 480, minHeight: 360)
                .onOpenURL { viewer.load($0) }
        }
        .defaultSize(width: 900, height: 740)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Markdown…") { viewer.chooseFile() }
                    .keyboardShortcut("o")
            }
            CommandGroup(replacing: .saveItem) {}
            CommandGroup(after: .newItem) {
                Button("Reload File") { viewer.reload() }
                    .keyboardShortcut("r")
                    .disabled(viewer.fileURL == nil)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

final class ViewerModel: ObservableObject {
    static let shared = ViewerModel()
    @Published private(set) var fileURL: URL?
    @Published private(set) var markdown = ""
    @Published var error: String?
    private var scopedURL: URL?

    func chooseFile() {
        let panel = NSOpenPanel()
        panel.title = "Open Markdown"
        panel.allowedContentTypes = [
            UTType(filenameExtension: "md") ?? .plainText,
            UTType(filenameExtension: "markdown") ?? .plainText,
            .plainText
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url { load(url) }
    }

    func load(_ url: URL) {
        guard url.isFileURL else { return }
        let hasAccess = url.startAccessingSecurityScopedResource()
        do {
            // Detect common text encodings instead of assuming every document is UTF-8.
            var encoding = String.Encoding.utf8
            let text = try String(contentsOf: url, usedEncoding: &encoding)
            scopedURL?.stopAccessingSecurityScopedResource()
            scopedURL = hasAccess ? url : nil
            markdown = text
            fileURL = url
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
        } catch {
            if hasAccess { url.stopAccessingSecurityScopedResource() }
            self.error = "Couldn’t open \(url.lastPathComponent). \(error.localizedDescription)"
        }
    }

    func reload() {
        if let fileURL { load(fileURL) }
    }
}

struct ViewerView: View {
    @ObservedObject var viewer: ViewerModel
    @State private var isDropTarget = false

    var body: some View {
        Group {
            if let url = viewer.fileURL {
                MarkdownWebView(markdown: viewer.markdown, fileURL: url)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "terminal")
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("> markymark_").font(.system(.largeTitle, design: .monospaced).bold())
                    Text("Drop a .md file. Enter reading mode.")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Button("Open Markdown…") { viewer.chooseFile() }
                        .controlSize(.large)
                        .keyboardShortcut("o")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .overlay {
            if isDropTarget {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
        .navigationTitle(viewer.fileURL?.lastPathComponent ?? "MarkyMark")
        .toolbar {
            ToolbarItem {
                Button { viewer.chooseFile() } label: {
                    Label("Open Markdown", systemImage: "folder")
                }
                .help("Open Markdown (⌘O)")
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTarget) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async { viewer.load(url) }
            }
            return true
        }
        .alert("Unable to Open File", isPresented: Binding(
            get: { viewer.error != nil },
            set: { if !$0 { viewer.error = nil } }
        )) {
            Button("OK") { viewer.error = nil }
        } message: {
            Text(viewer.error ?? "")
        }
    }
}

struct MarkdownWebView: NSViewRepresentable {
    let markdown: String
    let fileURL: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(context.coordinator.assets, forURLScheme: "markymark-local")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsBackForwardNavigationGestures = false
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        guard coordinator.markdown != markdown || coordinator.fileURL != fileURL else { return }
        coordinator.markdown = markdown
        coordinator.fileURL = fileURL
        coordinator.assets.directory = fileURL.deletingLastPathComponent()
        // Keep the page at about:blank. A custom-scheme page URL can be handed
        // to Launch Services by WebKit; only image requests need our scheme.
        webView.loadHTMLString(Renderer.html(markdown), baseURL: nil)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let assets = LocalAssets()
        var markdown: String?
        var fileURL: URL?

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            if url.absoluteString == "about:blank" || url.absoluteString.hasPrefix("about:blank#") {
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
                guard navigationAction.navigationType == .linkActivated else { return }
                if ["https", "http", "mailto"].contains(url.scheme?.lowercased() ?? "") {
                    NSWorkspace.shared.open(url)
                } else if url.scheme == "markymark-local", let local = assets.localURL(for: url),
                          ["md", "markdown", "txt"].contains(local.pathExtension.lowercased()) {
                    ViewerModel.shared.load(local)
                }
            }
        }
    }
}

// Serve relative images without giving page content unrestricted filesystem access.
final class LocalAssets: NSObject, WKURLSchemeHandler {
    var directory: URL?

    func localURL(for url: URL) -> URL? {
        guard url.host == "document", let directory else { return nil }
        let root = directory.resolvingSymlinksInPath().standardizedFileURL
        let file = root.appendingPathComponent(url.path).resolvingSymlinksInPath().standardizedFileURL
        guard file.path.hasPrefix(root.path + "/") else { return nil }
        return file
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url, let file = localURL(for: url),
              let type = UTType(filenameExtension: file.pathExtension), type.conforms(to: .image),
              let data = try? Data(contentsOf: file) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        urlSchemeTask.didReceive(URLResponse(url: url, mimeType: type.preferredMIMEType ?? "application/octet-stream",
                                            expectedContentLength: data.count, textEncodingName: nil))
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}

enum Renderer {
    private static func resourceData(_ name: String, extension ext: String) -> Data {
        let packaged = Bundle.main.resourceURL?
            .appendingPathComponent("MarkyMark_MarkyMark.bundle")
        let bundle = packaged.flatMap { Bundle(url: $0) } ?? Bundle.module
        guard let url = bundle.url(forResource: name, withExtension: ext),
              let data = try? Data(contentsOf: url) else {
            fatalError("Missing bundled resource: \(name).\(ext)")
        }
        return data
    }

    private static func resource(_ name: String, extension ext: String) -> String {
        String(decoding: resourceData(name, extension: ext), as: UTF8.self)
    }

    private static let marked = resource("marked", extension: "js")
    private static let purify = resource("purify", extension: "js")
    private static let css = resource("reader", extension: "css")
    private static let fontCSS = """
    @font-face {
      font-family: 'Marky Nerd';
      src: url(data:font/ttf;base64,\(resourceData("JetBrainsMonoNLNerdFontMono-Regular", extension: "ttf").base64EncodedString())) format('truetype');
      font-weight: 400;
      font-style: normal;
      font-display: swap;
    }
    """

    static func html(_ markdown: String) -> String {
        let encoded = Data(markdown.utf8).base64EncodedString()
        let nonce = UUID().uuidString
        return """
        <!doctype html>
        <html lang="en"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'nonce-\(nonce)'; style-src 'unsafe-inline'; font-src data:; img-src markymark-local: https: http: data:; base-uri 'none'; form-action 'none'">
        <style>\(fontCSS)\(css)</style>
        </head><body><header class="terminal-bar" aria-label="MarkyMark reader"><span aria-hidden="true">&#xf120; </span>markymark<span class="terminal-status">READ ONLY / LOCAL</span></header><main id="content" aria-label="Markdown document"></main>
        <script nonce="\(nonce)">\(marked)</script>
        <script nonce="\(nonce)">\(purify)</script>
        <script nonce="\(nonce)">
        const source = new TextDecoder().decode(Uint8Array.from(atob('\(encoded)'), c => c.charCodeAt(0)));
        document.getElementById('content').innerHTML = DOMPurify.sanitize(marked.parse(source, {gfm: true}), {
          USE_PROFILES: {html: true}, FORBID_TAGS: ['style', 'form', 'input'],
          FORBID_ATTR: ['style', 'srcset']
        });
        // Resolve document-relative assets without making the page itself a
        // custom-scheme URL. Fragment links remain on the about:blank page.
        document.querySelectorAll('img[src], a[href]').forEach(element => {
          const attribute = element.tagName === 'IMG' ? 'src' : 'href';
          const value = element.getAttribute(attribute);
          if (value.startsWith('#')) return;
          try {
            element.setAttribute(attribute, new URL(value, 'markymark-local://document/').href);
          } catch (_) { element.removeAttribute(attribute); }
        });
        // Stable anchors for common Markdown table-of-contents links.
        const ids = new Set();
        document.querySelectorAll('h1,h2,h3,h4,h5,h6').forEach(heading => {
          const base = heading.textContent.toLowerCase().replace(/[^\\p{L}\\p{N}_\\s-]/gu, '').trim().replace(/\\s/g, '-');
          let id = base, suffix = 0;
          while (ids.has(id)) id = base + '-' + (++suffix);
          ids.add(id); heading.id = id;
        });
        </script></body></html>
        """
    }
}
