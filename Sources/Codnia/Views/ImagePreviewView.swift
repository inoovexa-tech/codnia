import SwiftUI

struct ImagePreviewView: View {
    let path: String
    @State private var image: NSImage?
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
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundColor(.textTertiary)
                    Text("Failed to load image")
                        .font(.system(size: 13))
                        .foregroundColor(.textTertiary)
                }
            } else if let image = image {
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadImage() }
        .onChange(of: path) { _ in loadImage() }
    }

    private func loadImage() {
        isLoading = true
        loadFailed = false

        DispatchQueue.global(qos: .userInitiated).async {
            if let loadedImage = NSImage(contentsOfFile: path) {
                DispatchQueue.main.async {
                    self.image = loadedImage
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
