import SwiftUI

struct IconPickerView: View {
    let project: Project
    @ObservedObject var workspaceVM: WorkspaceService
    @Environment(\.presentationMode) var presentationMode

    @State private var selectedIcon: String? = nil
    @State private var detectedIcons: [String] = []
    @State private var showImageBrowser = false

    var body: some View {
        ZStack {
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
                    showImageBrowser = true
                }

                if selectedIcon != nil && project.customIconPath != nil {
                    Button("Remove Custom Icon") {
                        workspaceVM.updateProjectIcon(id: project.id, iconPath: nil)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.red)
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
                        } else {
                            workspaceVM.updateProjectIcon(id: project.id, iconPath: nil)
                        }
                        presentationMode.wrappedValue.dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 400, height: 300)

            if showImageBrowser {
                ImagePickerModalView(
                    isPresented: $showImageBrowser,
                    onSelect: { path in
                        selectedIcon = path
                    }
                )
            }
        }
        .onAppear {
            detectedIcons = findIconsInProject()
        }
    }

    private func findIconsInProject() -> [String] {
        let fm = FileManager.default
        let iconNames = [
            "favicon.ico",
            "icon.png",
            "logo.png",
            "icon.svg",
            "Icon.png",
            "apple-touch-icon.png",
            "apple-touch-icon-precomposed.png",
            "favicon.svg",
            "logo.svg",
            "logo.jpg",
            "logo.jpeg",
            "icon.webp",
            "favicon-16x16.png",
            "favicon-32x32.png",
            "android-chrome-192x192.png",
            "android-chrome-512x512.png",
            "mstile-150x150.png"
        ]
        return iconNames.compactMap { name in
            let path = (project.path as NSString).appendingPathComponent(name)
            return fm.fileExists(atPath: path) ? path : nil
        }
    }

    private func copyIconToAppSupport(originalPath: String) -> String? {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Codnia", isDirectory: true) else { return nil }
        try? fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
        let dest = appSupport.appendingPathComponent("\(project.id)_icon.png")
        try? fm.removeItem(at: dest)
        do {
            try fm.copyItem(atPath: originalPath, toPath: dest.path)
            return dest.path
        } catch {
            return originalPath
        }
    }
}