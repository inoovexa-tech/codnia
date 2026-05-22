import AppKit
import SwiftUI

extension DatabaseType {
    var brandColor: Color {
        .secondary
    }

    private func logoImage() -> NSImage {
        let name: String
        switch self {
        case .postgres: name = "postgres"
        case .mysql: name = "mysql"
        case .sqlite: name = "sqlite"
        }
        if let url = Bundle.module.url(forResource: name, withExtension: "png"),
           let image = NSImage(contentsOf: url)
        {
            image.isTemplate = true
            return image
        }
        return NSImage(systemSymbolName: "server.rack", accessibilityDescription: nil) ?? NSImage()
    }

    func logoView(size: CGFloat = 16) -> some View {
        Image(nsImage: logoImage())
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .foregroundColor(brandColor)
    }
}
