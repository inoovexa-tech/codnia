import SwiftUI
import PDFKit

struct PDFPreviewView: View {
    let path: String
    @State private var pdfDocument: PDFDocument?
    @State private var isLoading = true
    @State private var loadFailed = false

    var body: some View {
        ZStack {
            Color.bgPrimary

            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(0.8)
            } else if loadFailed {
                VStack(spacing: 12) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 48))
                        .foregroundColor(.textTertiary)
                    Text("Failed to load PDF")
                        .font(.system(size: 13))
                        .foregroundColor(.textTertiary)
                }
            } else if let pdfDocument = pdfDocument {
                PDFKitView(document: pdfDocument)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadPDF() }
        .onChange(of: path) { _ in loadPDF() }
    }

    private func loadPDF() {
        isLoading = true
        loadFailed = false

        DispatchQueue.global(qos: .userInitiated).async {
            let url = URL(fileURLWithPath: self.path)
            if let document = PDFDocument(url: url) {
                DispatchQueue.main.async {
                    self.pdfDocument = document
                    self.isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    self.loadFailed = true
                    self.isLoading = false
                }
            }
        }
    }
}

struct PDFKitView: NSViewRepresentable {
    let document: PDFDocument

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = NSColor(red: 0.05, green: 0.07, blue: 0.09, alpha: 1.0)
        return pdfView
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        nsView.document = document
    }
}
