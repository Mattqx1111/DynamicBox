import Cocoa
import SwiftUI

enum DragTarget: Equatable {
    case none
    case shelf
    case airdrop
}

struct StashedItem: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let name: String
    let ext: String
    let sizeString: String
    let icon: NSImage
    let addedAt: Date
    
    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.name = url.lastPathComponent
        self.ext = url.pathExtension.uppercased()
        self.addedAt = Date()
        
        let wsIcon = NSWorkspace.shared.icon(forFile: url.path)
        wsIcon.size = NSSize(width: 48, height: 48)
        self.icon = wsIcon
        
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB, .useGB]
            formatter.countStyle = .file
            self.sizeString = formatter.string(fromByteCount: size)
        } else {
            self.sizeString = "--"
        }
    }
}

struct MusicTrackInfo: Equatable {
    var title: String
    var artist: String
    var album: String
    var duration: Double
    var position: Double
    var isPlaying: Bool
    var artwork: NSImage?
    var playerApp: String
    
    static var sample: MusicTrackInfo {
        MusicTrackInfo(
            title: "DynamicBox Music",
            artist: "Mini Music Player",
            album: "Dynamic Island",
            duration: 180.0,
            position: 35.0,
            isPlaying: true,
            artwork: nil,
            playerApp: "Music"
        )
    }
}

enum WaveColor: String, CaseIterable, Identifiable {
    case orange = "Orange Sunset"
    case cyan = "Cyber Cyan"
    case emerald = "Neon Green"
    case purple = "Purple Pulse"
    case white = "Monochrome White"
    
    var id: String { rawValue }
    
    var gradient: LinearGradient {
        switch self {
        case .orange:
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.65, blue: 0.15), Color(red: 1.0, green: 0.25, blue: 0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .cyan:
            return LinearGradient(
                colors: [Color(red: 0.2, green: 0.85, blue: 1.0), Color(red: 0.05, green: 0.5, blue: 1.0)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .emerald:
            return LinearGradient(
                colors: [Color(red: 0.3, green: 0.95, blue: 0.4), Color(red: 0.1, green: 0.7, blue: 0.3)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .purple:
            return LinearGradient(
                colors: [Color(red: 0.9, green: 0.4, blue: 1.0), Color(red: 0.6, green: 0.2, blue: 0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .white:
            return LinearGradient(
                colors: [Color.white.opacity(0.9), Color.white.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

enum SlideDirection: Equatable {
    case forward
    case backward
}

enum NotchTab: String, CaseIterable, Identifiable {
    case music = "Music"
    case shelf = "Shelf"
    case notes = "Notes"
    case clipboard = "Clipboard"
    case timer = "Timer"
    
    var id: String { rawValue }
    
    var index: Int {
        switch self {
        case .music: return 0
        case .shelf: return 1
        case .notes: return 2
        case .clipboard: return 3
        case .timer: return 4
        }
    }
    
    var iconName: String {
        switch self {
        case .music: return "music.note"
        case .shelf: return "folder.fill"
        case .notes: return "note.text"
        case .clipboard: return "doc.on.clipboard.fill"
        case .timer: return "timer"
        }
    }
}

struct ClipboardItem: Identifiable, Equatable {
    let id: UUID
    let text: String
    let fileURLs: [URL]?
    let isFile: Bool
    let fileIcon: NSImage?
    let fileExtension: String?
    let date: Date
    
    init(text: String, fileURLs: [URL]? = nil) {
        self.id = UUID()
        self.text = text
        self.fileURLs = fileURLs
        self.isFile = (fileURLs != nil && !fileURLs!.isEmpty)
        self.date = Date()
        
        if let firstURL = fileURLs?.first {
            let icon = NSWorkspace.shared.icon(forFile: firstURL.path)
            icon.size = NSSize(width: 32, height: 32)
            self.fileIcon = icon
            let ext = firstURL.pathExtension.uppercased()
            self.fileExtension = ext.isEmpty ? "FILE" : ext
        } else {
            self.fileIcon = nil
            self.fileExtension = nil
        }
    }
    
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        if lhs.isFile && rhs.isFile {
            return lhs.fileURLs == rhs.fileURLs
        }
        return lhs.text == rhs.text
    }
}

enum NotchWingMode: Equatable {
    case symmetric
    case rightOnly
    case leftOnly
    case flush
}
