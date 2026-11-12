import AppKit
import UniformTypeIdentifiers
import WebKit

final class PDFExporter: ObservableObject {
    @Published var isReady = false
    @Published private(set) var isExporting = false
    weak var webView: WKWebView?
    var fileURL: URL?
    var documentID = UUID()

    var canExport: Bool { isReady && !isExporting && webView != nil }

    @MainActor
    func exportPDF() {
        guard canExport, let webView, !webView.isLoading, let fileURL else { return }
        let documentID = documentID
        let panel = NSSavePanel()
        panel.title = "Export as PDF"
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = fileURL.deletingPathExtension().lastPathComponent + ".pdf"
        panel.canCreateDirectories = true
        isExporting = true

        Task { @MainActor in
            defer { isExporting = false }
            do {
                let data = try await Self.pdfData(from: webView)
                guard self.documentID == documentID, !webView.isLoading else {
                    throw ExportError.documentChanged
                }
                guard panel.runModal() == .OK, let url = panel.url else { return }
                try data.write(to: url, options: .atomic)
            } catch {
                ViewerModel.shared.error = "Couldn’t export PDF. \(error.localizedDescription)"
            }
        }
    }

    @MainActor
    static func pdfData(from webView: WKWebView) async throws -> Data {
        // Capture screen styling directly, including the current appearance. A
        // full-document rect avoids clipping to the visible, scrolled viewport.
        let size = try await webView.callAsyncJavaScript("""
        await document.fonts.ready;
        await Promise.all(Array.from(document.images, image => {
          if (image.complete) return Promise.resolve();
          return new Promise(resolve => {
            image.addEventListener('load', resolve, {once: true});
            image.addEventListener('error', resolve, {once: true});
          });
        }));
        return {width: document.documentElement.clientWidth,
                height: Math.max(document.documentElement.scrollHeight, document.body.scrollHeight)};
        """, arguments: [:], in: nil, contentWorld: .page)
        guard let size = size as? [String: Double],
              let width = size["width"], let height = size["height"], width > 0, height > 0 else {
            throw ExportError.invalidSize
        }
        let configuration = WKPDFConfiguration()
        configuration.rect = CGRect(x: 0, y: 0, width: width, height: height)
        return try await webView.pdf(configuration: configuration)
    }

    private enum ExportError: LocalizedError {
        case documentChanged, invalidSize

        var errorDescription: String? {
            switch self {
            case .documentChanged: return "The document changed during export. Please try again."
            case .invalidSize: return "The rendered document has no exportable size."
            }
        }
    }
}
