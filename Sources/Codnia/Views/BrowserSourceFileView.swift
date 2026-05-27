import SwiftUI
import WebKit

struct BrowserSourceFileView: View {
    let resource: BrowserResourceEntry
    @State private var content: String = ""
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            if isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 20))
                        .foregroundColor(.accentYellow)
                    Text("Failed to load")
                        .font(.system(size: 11))
                        .foregroundColor(.textSecondary)
                    Text(error)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.textTertiary)
                        .lineLimit(3)
                }
                Spacer()
            } else {
                ScrollView([.horizontal, .vertical]) {
                    SyntaxHighlightedText(text: content, language: resource.language)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .background(Color.bgPrimary)
            }
        }
        .onAppear {
            loadContent()
        }
    }

    private var headerBar: some View {
        HStack(spacing: 4) {
            Image(systemName: "doc.text")
                .font(.system(size: 9))
                .foregroundColor(.textTertiary)
            Text(resource.fileName)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.textPrimary)
                .lineLimit(1)
            Spacer()
            Text(resource.language)
                .font(.system(size: 8))
                .foregroundColor(.textTertiary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.bgTertiary)
                .cornerRadius(3)
            Text(resource.url)
                .font(.system(size: 8))
                .foregroundColor(.textTertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.bgSecondary)
        .overlay(Rectangle().frame(height: 1).foregroundColor(.borderDefault), alignment: .bottom)
    }

    private func loadContent() {
        guard let url = URL(string: resource.url) else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }

        // Only load text-based resources
        let textExtensions = ["js", "ts", "css", "html", "htm", "json", "xml", "svg",
                              "swift", "py", "rb", "php", "java", "rs", "go",
                              "md", "yaml", "yml", "sh", "bash", "zsh", "txt",
                              "c", "cpp", "h", "hpp", "m", "mm"]
        let ext = resource.pathExtension.lowercased()

        guard textExtensions.contains(ext) || resource.mimeType.contains("text") || resource.mimeType.contains("javascript") || resource.mimeType.contains("json") else {
            errorMessage = "Binary file (\(ext)) cannot be previewed"
            isLoading = false
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    errorMessage = error.localizedDescription
                    return
                }
                guard let data = data, let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
                    errorMessage = "Unable to decode file content"
                    return
                }
                content = text
            }
        }.resume()
    }
}
