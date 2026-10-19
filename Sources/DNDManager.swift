import Cocoa

class DNDManager {
    static let shared = DNDManager()
    
    private var cachedShortcutID: String? = nil
    
    init() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            _ = self?.findDNDShortcut()
        }
    }
    
    func findDNDShortcut() -> String? {
        if let cached = cachedShortcutID, !cached.isEmpty {
            return cached
        }
        
        let script = """
        tell application "Shortcuts"
            try
                repeat with s in shortcuts
                    set sName to (name of s as string)
                    set sId to (id of s as string)
                    if sName contains "DND" or sName contains "Disturb" or sName contains "Фокус" or sName contains "Focus" or sId is "E2A3155F-D9B2-4059-8E04-DC3553AC391A" then
                        return sId
                    end if
                end repeat
            end try
            return ""
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var err: NSDictionary?
            let result = appleScript.executeAndReturnError(&err).stringValue ?? ""
            if !result.isEmpty {
                self.cachedShortcutID = result
                return result
            }
        }
        
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["list"]
        process.standardOutput = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
                for candidate in ["DND", "DND Raycast", "Do Not Disturb", "Не беспокоить", "Focus"] {
                    if lines.contains(candidate) {
                        self.cachedShortcutID = candidate
                        return candidate
                    }
                }
            }
        } catch {}
        
        return nil
    }
    
    func isShortcutInstalled() -> Bool {
        return findDNDShortcut() != nil
    }
    
    func installShortcutIfNeeded() {
        if isShortcutInstalled() { return }
        
        let bundlePath = Bundle.main.path(forResource: "DND", ofType: "shortcut") ??
                         "/Applications/DynamicBox.app/Contents/Resources/DND.shortcut"
        if FileManager.default.fileExists(atPath: bundlePath) {
            NSWorkspace.shared.open(URL(fileURLWithPath: bundlePath))
        }
    }
    
    func setDND(active: Bool, completion: ((Bool) -> Void)? = nil) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            if let shortcutTarget = self.findDNDShortcut() {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
                process.arguments = ["run", shortcutTarget]
                
                let inPipe = Pipe()
                process.standardInput = inPipe
                let cmd = active ? "on" : "off"
                if let data = cmd.data(using: .utf8) {
                    try? inPipe.fileHandleForWriting.write(contentsOf: data)
                    try? inPipe.fileHandleForWriting.close()
                }
                
                try? process.run()
                process.waitUntilExit()
                
                if process.terminationStatus != 0 {
                    let sanitizedTarget = shortcutTarget
                        .replacingOccurrences(of: "\\", with: "\\\\")
                        .replacingOccurrences(of: "\"", with: "\\\"")
                    let runScript = """
                    tell application "Shortcuts"
                        try
                            run (first shortcut whose id is "\(sanitizedTarget)")
                        end try
                    end tell
                    """
                    if let asScript = NSAppleScript(source: runScript) {
                        var err: NSDictionary?
                        asScript.executeAndReturnError(&err)
                    }
                }
                
                DispatchQueue.main.async {
                    completion?(active)
                }
                return
            }
            
            DispatchQueue.main.async {
                self.installShortcutIfNeeded()
                completion?(active)
            }
        }
    }
}
