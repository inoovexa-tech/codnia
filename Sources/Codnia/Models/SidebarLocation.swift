import Foundation

public enum SidebarSection: String, CaseIterable, Identifiable {
    case favorites
    case icloud
    case locations

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .favorites: return "Favorites"
        case .icloud: return "iCloud"
        case .locations: return "Locations"
        }
    }
}

public enum SidebarLocation: Identifiable, Hashable {
    case airDrop
    case recents
    case applications
    case desktop
    case documents
    case downloads
    case home
    case pictures
    case music
    case movies
    case icloudDrive
    case mobileDocuments
    case volume(name: String, path: String)
    case root

    public var id: String {
        switch self {
        case .airDrop: return "favorites.airdrop"
        case .recents: return "favorites.recents"
        case .applications: return "favorites.applications"
        case .desktop: return "favorites.desktop"
        case .documents: return "favorites.documents"
        case .downloads: return "favorites.downloads"
        case .home: return "favorites.home"
        case .pictures: return "favorites.pictures"
        case .music: return "favorites.music"
        case .movies: return "favorites.movies"
        case .icloudDrive: return "icloud.drive"
        case .mobileDocuments: return "icloud.mobileDocuments"
        case .volume(let name, _): return "volume.\(name)"
        case .root: return "locations.root"
        }
    }

    public var section: SidebarSection {
        switch self {
        case .airDrop, .recents, .applications, .desktop, .documents,
             .downloads, .home, .pictures, .music, .movies:
            return .favorites
        case .icloudDrive, .mobileDocuments:
            return .icloud
        case .volume, .root:
            return .locations
        }
    }

    public var title: String {
        switch self {
        case .airDrop: return "AirDrop"
        case .recents: return "Recents"
        case .applications: return "Applications"
        case .desktop: return "Desktop"
        case .documents: return "Documents"
        case .downloads: return "Downloads"
        case .home: return NSUserName()
        case .pictures: return "Pictures"
        case .music: return "Music"
        case .movies: return "Movies"
        case .icloudDrive: return "iCloud Drive"
        case .mobileDocuments: return "Mobile Documents"
        case .volume(let name, _): return name
        case .root: return "Macintosh HD"
        }
    }

    public var systemImage: String {
        switch self {
        case .airDrop: return "wifi"
        case .recents: return "clock.arrow.circlepath"
        case .applications: return "app.badge.fill"
        case .desktop: return "desktopcomputer"
        case .documents: return "doc.on.doc.fill"
        case .downloads: return "arrow.down.circle.fill"
        case .home: return "house.fill"
        case .pictures: return "photo.on.rectangle.angled"
        case .music: return "music.note"
        case .movies: return "film.fill"
        case .icloudDrive: return "icloud.fill"
        case .mobileDocuments: return "folder.fill.badge.gearshape"
        case .volume: return "externaldrive.fill"
        case .root: return "internaldrive.fill"
        }
    }

    public var path: String? {
        switch self {
        case .airDrop, .recents:
            return nil
        case .applications:
            return "/Applications"
        case .desktop:
            return NSString(string: "~/Desktop").expandingTildeInPath
        case .documents:
            return NSString(string: "~/Documents").expandingTildeInPath
        case .downloads:
            return NSString(string: "~/Downloads").expandingTildeInPath
        case .home:
            return NSHomeDirectory()
        case .pictures:
            return NSString(string: "~/Pictures").expandingTildeInPath
        case .music:
            return NSString(string: "~/Music").expandingTildeInPath
        case .movies:
            return NSString(string: "~/Movies").expandingTildeInPath
        case .icloudDrive:
            return FileSystemService.iCloudDriveURL?.path
        case .mobileDocuments:
            return NSString(string: "~/Library/Mobile Documents").expandingTildeInPath
        case .volume(_, let path):
            return path
        case .root:
            return "/"
        }
    }

    public var isSelectable: Bool {
        path != nil && self != .airDrop
    }

    public static var allFavorites: [SidebarLocation] {
        [.airDrop, .recents, .applications, .desktop, .documents,
         .downloads, .home, .pictures, .music, .movies]
    }

    public static func availableLocations() -> [SidebarLocation] {
        let fm = FileManager.default
        var locations: [SidebarLocation] = []
        for loc in allFavorites {
            if loc == .airDrop || loc == .recents { continue }
            if let p = loc.path, fm.fileExists(atPath: p) {
                locations.append(loc)
            }
        }
        if FileSystemService.iCloudDriveURL != nil {
            locations.append(.icloudDrive)
        }
        let mobileDocs = NSString(string: "~/Library/Mobile Documents").expandingTildeInPath
        if fm.fileExists(atPath: mobileDocs) {
            locations.append(.mobileDocuments)
        }
        locations.append(.root)
        for v in FileSystemService.mountedVolumes {
            locations.append(.volume(name: v.lastPathComponent, path: v.path))
        }
        return locations
    }
}
