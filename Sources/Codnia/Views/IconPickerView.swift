import SwiftUI
import AppKit

struct IconPickerView: View {
    let project: Project
    @ObservedObject var workspaceVM: WorkspaceService
    @Environment(\.presentationMode) var presentationMode

    @State private var selectedIcon: String? = nil
    @State private var detectedIcons: [String] = []

    var body: some View {
        VStack(spacing: 16) {
            Text("Select Project Icon")
                .font(.headline)

            if !detectedIcons.isEmpty {
                Text("Detected icons in project:")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(detectedIcons, id: \.self) { iconPath in
                            if let nsImage = NSImage(contentsOfFile: iconPath) {
                                Button(action: {
                                    selectedIcon = iconPath
                                }) {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .frame(width: 48, height: 48)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(selectedIcon == iconPath ? Color.accentBlue : Color.clear, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }

            Button("Choose Custom Image...") {
                chooseCustomImage()
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Apply") {
                    if let iconPath = selectedIcon {
                        let persistedPath = copyIconToAppSupport(originalPath: iconPath)
                        workspaceVM.updateProjectIcon(id: project.id, iconPath: persistedPath ?? iconPath)
                    }
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedIcon == nil)
            }
        }
        .padding(24)
        .frame(width: 400, height: 300)
        .onAppear {
            detectedIcons = findIconsInProject()
        }
    }

    private func findIconsInProject() -> [String] {
        let fm = FileManager.default
        let iconNames = ["favicon.ico", "icon.png", "logo.png", "icon.svg", "Icon.png", "icon.jpg", "logo.jpg"]
        return iconNames.compactMap { name in
            let path = (project.path as NSString).appendingPathComponent(name)
            return fm.fileExists(atPath: path) ? path : nil
        }
    }

    private func chooseCustomImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .ico, .svg]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            selectedIcon = url.path
        }
    }

    private func copyIconToAppSupport(originalPath: String) -> String? {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Codnia", isDirectory: true) else { return nil }
        try? fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
        let dest = appSupport.appendingPathComponent("\(project.id)_icon.png")
        // Remove existing file if any
        try? fm.removeItem(at: dest)
        do {
            try fm.copyItem(atPath: originalPath, toPath: dest.path)
            return dest.path
        } catch {
            return originalPath
        }
    }
}