import Cocoa
import CoreAudio

class MediaController {
    static let shared = MediaController()
    
    private typealias MRRegisterFunc = @convention(c) (DispatchQueue) -> Void
    private typealias MRGetNowPlayingInfoFunc = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
    private typealias MRGetClientFunc = @convention(c) (DispatchQueue, @escaping (AnyObject?) -> Void) -> Void
    private typealias MRSendCommandFunc = @convention(c) (Int32, AnyObject?) -> Bool
    
    private var getInfoFunc: MRGetNowPlayingInfoFunc?
    private var getClientFunc: MRGetClientFunc?
    private var sendCommandFunc: MRSendCommandFunc?
    
    private var cachedTrackKey: String = ""
    private var cachedArtwork: NSImage?
    private var cachedClientName: String = "Media"
    
    private var artworkCache: [String: NSImage] = [:]
    private var pendingArtworkFetches = Set<String>()
    var onArtworkUpdated: ((String, NSImage) -> Void)?
    
    init() {
        if let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")) {
            if let regPtr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteRegisterForNowPlayingNotifications" as CFString) {
                let regFn = unsafeBitCast(regPtr, to: MRRegisterFunc.self)
                regFn(DispatchQueue.main)
            }
            if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) {
                getInfoFunc = unsafeBitCast(ptr, to: MRGetNowPlayingInfoFunc.self)
            }
            if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingClient" as CFString) {
                getClientFunc = unsafeBitCast(ptr, to: MRGetClientFunc.self)
            }
            if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSendCommand" as CFString) {
                sendCommandFunc = unsafeBitCast(ptr, to: MRSendCommandFunc.self)
            }
        }
    }
    
    func getNowPlaying() -> MusicTrackInfo? {
        if let info = queryMediaRemote() {
            return info
        }
        
        if isAppRunning("com.apple.Music") {
            if let info = queryAppleMusic() {
                return info
            }
        }
        
        if isAppRunning("com.spotify.client") {
            if let info = querySpotify() {
                return info
            }
        }
        
        return nil
    }
    
    private func queryMediaRemote() -> MusicTrackInfo? {
        guard let getInfo = getInfoFunc else { return nil }
        
        var result: MusicTrackInfo? = nil
        let sema = DispatchSemaphore(value: 0)
        
        getInfo(DispatchQueue.global(qos: .userInitiated)) { [weak self] dict in
            guard let self = self else {
                sema.signal()
                return
            }
            
            if let title = dict["kMRMediaRemoteNowPlayingInfoTitle"] as? String,
               !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                
                let artist = dict["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
                let album = dict["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? ""
                let rate = dict["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0.0
                let duration = dict["kMRMediaRemoteNowPlayingInfoDuration"] as? Double ?? 0.0
                let position = dict["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double ?? 0.0
                let isPlaying = (rate > 0.0)
                
                let trackKey = "\(title):\(artist)".trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                var art: NSImage? = nil
                
                if let cached = self.artworkCache[trackKey] {
                    art = cached
                } else if let artData = dict["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data,
                          let img = NSImage(data: artData) {
                    art = img
                    self.artworkCache[trackKey] = img
                } else if let artId = dict["kMRMediaRemoteNowPlayingInfoArtworkIdentifier"] as? String,
                          artId.hasPrefix("http") {
                    self.fetchArtworkFromURL(artId, trackKey: trackKey)
                } else {
                    self.fetchArtworkFromFallback(title: title, artist: artist, trackKey: trackKey)
                }
                
                self.cachedTrackKey = trackKey
                self.cachedArtwork = art
                
                let appName = self.detectClientAppName(from: dict)
                
                result = MusicTrackInfo(
                    title: title,
                    artist: artist.isEmpty ? appName : artist,
                    album: album,
                    duration: max(duration, 1.0),
                    position: position,
                    isPlaying: isPlaying,
                    artwork: art,
                    playerApp: appName
                )
            }
            sema.signal()
        }
        
        _ = sema.wait(timeout: .now() + 0.35)
        return result
    }
    
    private func detectClientAppName(from dict: [String: Any]) -> String {
        if let getClient = getClientFunc {
            let sema = DispatchSemaphore(value: 0)
            getClient(DispatchQueue.global(qos: .userInitiated)) { [weak self] client in
                if let client = client {
                    let desc = String(describing: client).lowercased()
                    if desc.contains("safari") {
                        self?.cachedClientName = "Safari"
                    } else if desc.contains("chrome") {
                        self?.cachedClientName = "Chrome"
                    } else if desc.contains("youtube") {
                        self?.cachedClientName = "YouTube"
                    } else if desc.contains("music") {
                        self?.cachedClientName = "Music"
                    } else if desc.contains("spotify") {
                        self?.cachedClientName = "Spotify"
                    } else if desc.contains("quicktime") {
                        self?.cachedClientName = "QuickTime"
                    } else if desc.contains("vlc") {
                        self?.cachedClientName = "VLC"
                    } else if desc.contains("iina") {
                        self?.cachedClientName = "IINA"
                    } else if desc.contains("telegram") {
                        self?.cachedClientName = "Telegram"
                    }
                }
                sema.signal()
            }
            _ = sema.wait(timeout: .now() + 0.05)
        }
        return cachedClientName
    }
    
    private func isAppRunning(_ bundleID: String) -> Bool {
        return NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleID }
    }
    
    private func queryAppleMusic() -> MusicTrackInfo? {
        let script = """
        tell application id "com.apple.Music"
            try
                if player state is not stopped then
                    set tName to name of current track
                    set tArtist to artist of current track
                    set tAlbum to album of current track
                    set tDur to (duration of current track as string)
                    set tPos to (player position as string)
                    set pState to (player state as string)
                    set isFav to "false"
                    try
                        if favorited of current track is true then
                            set isFav to "true"
                        end if
                    on error
                        try
                            if loved of current track is true then
                                set isFav to "true"
                            end if
                        end try
                    end try
                    return tName & "|||" & tArtist & "|||" & tAlbum & "|||" & tDur & "|||" & tPos & "|||" & pState & "|||" & isFav
                else
                    return "STOPPED"
                end if
            on error
                return "ERROR"
            end try
        end tell
        """
        guard let output = executeAppleScript(script), output != "STOPPED", output != "ERROR" else { return nil }
        return parseOutput(output, playerApp: "Music", bundleID: "com.apple.Music")
    }
    
    private func querySpotify() -> MusicTrackInfo? {
        let script = """
        tell application id "com.spotify.client"
            try
                if player state is not stopped then
                    set tName to name of current track
                    set tArtist to artist of current track
                    set tAlbum to album of current track
                    set tDur to ((duration of current track) / 1000) as string
                    set tPos to (player position as string)
                    set pState to (player state as string)
                    return tName & "|||" & tArtist & "|||" & tAlbum & "|||" & tDur & "|||" & tPos & "|||" & pState
                else
                    return "STOPPED"
                end if
            on error
                return "ERROR"
            end try
        end tell
        """
        guard let output = executeAppleScript(script), output != "STOPPED", output != "ERROR" else { return nil }
        return parseOutput(output, playerApp: "Spotify", bundleID: "com.spotify.client")
    }
    
    private func parseOutput(_ output: String, playerApp: String, bundleID: String) -> MusicTrackInfo? {
        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 6 else { return nil }
        
        let title = parts[0]
        let artist = parts[1]
        let album = parts[2]
        
        let durStr = parts[3].replacingOccurrences(of: ",", with: ".")
        let posStr = parts[4].replacingOccurrences(of: ",", with: ".")
        
        let duration = Double(durStr) ?? 0.0
        let position = Double(posStr) ?? 0.0
        let stateStr = parts[5].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isPlaying = (stateStr == "playing")
        
        let isLiked = (parts.count >= 7 && parts[6].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "true")
        
        let trackKey = "\(title):\(artist)".trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let art: NSImage?
        if let cached = artworkCache[trackKey] {
            art = cached
        } else {
            let fetched = fetchArtwork(forBundleID: bundleID, trackKey: trackKey)
            if let f = fetched {
                artworkCache[trackKey] = f
                art = f
            } else {
                fetchArtworkFromFallback(title: title, artist: artist, trackKey: trackKey)
                art = nil
            }
            cachedTrackKey = trackKey
            cachedArtwork = art
        }
        
        return MusicTrackInfo(
            title: title.isEmpty ? "Track" : title,
            artist: artist.isEmpty ? "Unknown Artist" : artist,
            album: album,
            duration: max(duration, 1.0),
            position: position,
            isPlaying: isPlaying,
            artwork: art,
            playerApp: playerApp,
            isLiked: isLiked
        )
    }
    
    private func fetchArtwork(forBundleID bundleID: String, trackKey: String) -> NSImage? {
        if bundleID == "com.apple.Music" {
            let artScript = """
            tell application id "com.apple.Music"
                try
                    if (count of artworks of current track) > 0 then
                        return raw data of artwork 1 of current track
                    end if
                end try
            end tell
            """
            if let script = NSAppleScript(source: artScript) {
                var err: NSDictionary?
                let desc = script.executeAndReturnError(&err)
                if !desc.data.isEmpty {
                    return NSImage(data: desc.data)
                }
            }
        } else if bundleID == "com.spotify.client" {
            let artScript = """
            tell application id "com.spotify.client"
                try
                    return artwork url of current track
                end try
            end tell
            """
            if let urlStr = executeAppleScript(artScript), urlStr.hasPrefix("http") {
                fetchArtworkFromURL(urlStr, trackKey: trackKey)
            }
        }
        return nil
    }
    
    private func fetchArtworkFromURL(_ urlString: String, trackKey: String) {
        guard !pendingArtworkFetches.contains(trackKey) else { return }
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return }
        
        pendingArtworkFetches.insert(trackKey)
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self, let data = data, let image = NSImage(data: data) else { return }
            DispatchQueue.main.async {
                self.artworkCache[trackKey] = image
                self.pendingArtworkFetches.remove(trackKey)
                self.onArtworkUpdated?(trackKey, image)
            }
        }.resume()
    }
    
    private func fetchArtworkFromFallback(title: String, artist: String, trackKey: String) {
        guard !pendingArtworkFetches.contains(trackKey) else { return }
        guard !title.isEmpty, title != "Media Playback", title != "Audio Output" else { return }
        
        if isAppRunning("com.spotify.client") {
            let script = "tell application id \"com.spotify.client\" to return artwork url of current track"
            if let urlStr = executeAppleScript(script), urlStr.hasPrefix("http") {
                fetchArtworkFromURL(urlStr, trackKey: trackKey)
                return
            }
        }
        
        pendingArtworkFetches.insert(trackKey)
        
        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: "\(artist) \(title)"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "1")
        ]
        guard let url = components?.url else {
            pendingArtworkFetches.remove(trackKey)
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self else { return }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first,
                  let art100 = first["artworkUrl100"] as? String else {
                DispatchQueue.main.async {
                    self.pendingArtworkFetches.remove(trackKey)
                }
                return
            }
            let artHighRes = art100.replacingOccurrences(of: "100x100bb", with: "600x600bb")
            if let imgUrl = URL(string: artHighRes),
               let scheme = imgUrl.scheme?.lowercased(),
               scheme == "http" || scheme == "https" {
                URLSession.shared.dataTask(with: imgUrl) { [weak self] imgData, _, _ in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        self.pendingArtworkFetches.remove(trackKey)
                        if let imgData = imgData, let img = NSImage(data: imgData) {
                            self.artworkCache[trackKey] = img
                            self.onArtworkUpdated?(trackKey, img)
                        }
                    }
                }.resume()
            } else {
                DispatchQueue.main.async {
                    self.pendingArtworkFetches.remove(trackKey)
                }
            }
        }.resume()
    }
    
    func playPause() {
        if let send = sendCommandFunc {
            _ = send(2, nil)
            return
        }
        if isAppRunning("com.apple.Music") {
            _ = executeAppleScript("tell application id \"com.apple.Music\" to playpause")
        } else if isAppRunning("com.spotify.client") {
            _ = executeAppleScript("tell application id \"com.spotify.client\" to playpause")
        }
    }
    
    func nextTrack() {
        if let send = sendCommandFunc {
            _ = send(4, nil)
            return
        }
        if isAppRunning("com.apple.Music") {
            _ = executeAppleScript("tell application id \"com.apple.Music\" to next track")
        } else if isAppRunning("com.spotify.client") {
            _ = executeAppleScript("tell application id \"com.spotify.client\" to next track")
        }
    }
    
    func previousTrack() {
        if let send = sendCommandFunc {
            _ = send(5, nil)
            return
        }
        if isAppRunning("com.apple.Music") {
            _ = executeAppleScript("tell application id \"com.apple.Music\" to previous track")
        } else if isAppRunning("com.spotify.client") {
            _ = executeAppleScript("tell application id \"com.spotify.client\" to previous track")
        }
    }
    
    func seek(to position: Double) {
        let pos = max(0.0, position)
        
        if isAppRunning("com.apple.Music") {
            let script = "tell application id \"com.apple.Music\" to set player position to \(String(format: "%.1f", locale: Locale(identifier: "en_US"), pos))"
            _ = executeAppleScript(script)
        }
        
        if isAppRunning("com.spotify.client") {
            let script = "tell application id \"com.spotify.client\" to set player position to \(String(format: "%.1f", locale: Locale(identifier: "en_US"), pos))"
            _ = executeAppleScript(script)
        }
        
        if let send = sendCommandFunc {
            let opts: [String: Any] = ["kMRMediaRemoteOptionPlaybackPosition": pos]
            _ = send(16, opts as AnyObject)
        }
    }
    
    func seekBy(seconds: Double) {
        if let cur = getNowPlaying() {
            let newPos = max(0.0, min(cur.duration, cur.position + seconds))
            seek(to: newPos)
        }
    }
    
    func setLiked(_ liked: Bool) {
        if isAppRunning("com.apple.Music") {
            let val = liked ? "true" : "false"
            let script = """
            tell application id "com.apple.Music"
                try
                    set favorited of current track to \(val)
                on error
                    try
                        set loved of current track to \(val)
                    end try
                end try
            end tell
            """
            _ = executeAppleScript(script)
        }
    }
    
    private func executeAppleScript(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        return result.stringValue
    }
}
