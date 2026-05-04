import SwiftUI

struct MarkdownPreviewView: View {
    let content: String

    var body: some View {
        ScrollView {
            Text(renderedMarkdown)
                .font(.system(size: 14))
                .foregroundColor(.textPrimary)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.bgPrimary)
    }

    private var renderedMarkdown: String {
        // Simple conversion - in production use a proper markdown parser
        var result = content
        // Headers
        result = result.replacingOccurrences(of: "^# ", with: "", options: .regularExpression)
        // Bold
        result = result.replacingOccurrences(of: "\\*\\*", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "__", with: "")
        return result
    }
}
