import Cocoa
import SwiftUI
import Combine

class NotchViewModel: ObservableObject {
    @Published var isExpanded: Bool = false
    @Published var activeTab: NotchTab = .music
    @Published var slideDirection: SlideDirection = .forward
    @Published var showSettingsInline: Bool = false
    @Published var isCameraMirrorOpen: Bool = false
    @Published var isFlushToTop: Bool = true
    @Published var isDragHovering: Bool = false
    @Published var dragHoverTarget: DragTarget = .none
    @Published var isMouseHovering: Bool = false
    @Published var isFullScreenActive: Bool = false
    @Published var isMenuCrowded: Bool = false
    @Published var wingMode: NotchWingMode = .symmetric
    @Published var isScrubbingTrack: Bool = false
    
    @Published var showMusicInNotch: Bool = true {
        didSet { UserDefaults.standard.set(showMusicInNotch, forKey: "nb_show_music_notch") }
    }
    @Published var keepMusicWhenPaused: Bool = true {
        didSet { UserDefaults.standard.set(keepMusicWhenPaused, forKey: "nb_keep_music_paused") }
    }
    @Published var showTimerInNotch: Bool = true {
        didSet { UserDefaults.standard.set(showTimerInNotch, forKey: "nb_show_timer_notch") }
    }
    @Published var isOuterPanelHidden: Bool = false {
        didSet { UserDefaults.standard.set(isOuterPanelHidden, forKey: "nb_outer_panel_hidden") }
    }
    @Published var waveColor: WaveColor = .orange {
        didSet { UserDefaults.standard.set(waveColor.rawValue, forKey: "nb_wave_color") }
    }
    
    @Published var stashedFiles: [StashedItem] = []
    
    @Published var currentTrack: MusicTrackInfo? = nil
    @Published var equalizerHeights: [CGFloat] = [6, 12, 18, 10, 8]
    
    @Published var isTimerActive: Bool = false
    @Published var timerSecondsRemaining: Int = 25 * 60
    @Published var timerPresetDuration: Int = 25 * 60
    
    @Published var isDNDActive: Bool = false
    
    @Published var batteryPercent: Int = 100
    @Published var isCharging: Bool = false
    @Published var isPluggedIn: Bool = false
    @Published var showChargingBanner: Bool = false
    private var chargingBannerWorkItem: DispatchWorkItem?
    
    var timerString: String {
        let m = timerSecondsRemaining / 60
        let s = timerSecondsRemaining % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    @Published var quickNotes: String = "" {
        didSet { UserDefaults.standard.set(quickNotes, forKey: "notchbox_quick_notes") }
    }
    @Published var clipboardHistory: [ClipboardItem] = []
    
    private var collapseWorkItem: DispatchWorkItem?
    private var musicTimer: Timer?
    private var equalizerTimer: Timer?
    private var clipboardTimer: Timer?
    private var pomodoroTimer: Timer?
    private var lastPasteboardChangeCount: Int = 0
    
    var onOpenSettings: (() -> Void)? = nil
    
    init() {
        self.quickNotes = UserDefaults.standard.string(forKey: "notchbox_quick_notes") ?? ""
        self.showMusicInNotch = UserDefaults.standard.object(forKey: "nb_show_music_notch") as? Bool ?? true
        self.keepMusicWhenPaused = UserDefaults.standard.object(forKey: "nb_keep_music_paused") as? Bool ?? true
        self.showTimerInNotch = UserDefaults.standard.object(forKey: "nb_show_timer_notch") as? Bool ?? true
        self.isOuterPanelHidden = UserDefaults.standard.bool(forKey: "nb_outer_panel_hidden")
        if let savedColor = UserDefaults.standard.string(forKey: "nb_wave_color"),
           let c = WaveColor(rawValue: savedColor) {
            self.waveColor = c
        }
        
        let pb = NSPasteboard.general
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            let names = urls.map { $0.lastPathComponent }.joined(separator: ", ")
            clipboardHistory.append(ClipboardItem(text: names, fileURLs: urls))
        } else if let str = pb.string(forType: .string), !str.isEmpty {
            clipboardHistory.append(ClipboardItem(text: str))
        }
        lastPasteboardChangeCount = NSPasteboard.general.changeCount
        
        self.isDNDActive = UserDefaults.standard.bool(forKey: "nb_dnd_active")
        
        self.currentTrack = MediaController.shared.getNowPlaying()
        if self.currentTrack != nil {
            self.activeTab = .music
        } else {
            self.activeTab = .shelf
        }
        
        MediaController.shared.onArtworkUpdated = { [weak self] trackKey, image in
            guard let self = self, let current = self.currentTrack else { return }
            let key = "\(current.title):\(current.artist)"
            if key == trackKey {
                self.currentTrack?.artwork = image
            }
        }
        
        BatteryManager.shared.onChargerConnected = { [weak self] pct in
            self?.triggerChargingBanner(percent: pct)
        }
        BatteryManager.shared.onBatteryUpdated = { [weak self] pct, isChg, isPlug in
            self?.batteryPercent = pct
            self?.isCharging = isChg
            self?.isPluggedIn = isPlug
        }
        
        startTimers()
    }
    
    deinit {
        musicTimer?.invalidate()
        equalizerTimer?.invalidate()
        clipboardTimer?.invalidate()
        pomodoroTimer?.invalidate()
        chargingBannerWorkItem?.cancel()
    }
    
    private func startTimers() {
        let mTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                let track = MediaController.shared.getNowPlaying()
                DispatchQueue.main.async {
                    if let newTrack = track {
                        if self.isScrubbingTrack, let existing = self.currentTrack {
                            var updated = newTrack
                            updated.position = existing.position
                            self.currentTrack = updated
                        } else {
                            self.currentTrack = newTrack
                        }
                    } else {
                        self.currentTrack = nil
                    }
                }
            }
        }
        RunLoop.main.add(mTimer, forMode: .common)
        self.musicTimer = mTimer
        
        let eqTimer = Timer(timeInterval: 0.12, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.currentTrack?.isPlaying == true {
                DispatchQueue.main.async {
                    self.equalizerHeights = (0..<5).map { _ in CGFloat.random(in: 4...22) }
                }
            } else {
                DispatchQueue.main.async {
                    self.equalizerHeights = [3, 4, 3, 4, 3]
                }
            }
        }
        RunLoop.main.add(eqTimer, forMode: .common)
        self.equalizerTimer = eqTimer
        
        let clipTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let pb = NSPasteboard.general
            let count = pb.changeCount
            if count != self.lastPasteboardChangeCount {
                self.lastPasteboardChangeCount = count
                
                let concealedTypes: [NSPasteboard.PasteboardType] = [
                    NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"),
                    NSPasteboard.PasteboardType("com.agilebits.onepassword"),
                    NSPasteboard.PasteboardType("org.nspasteboard.TransientType"),
                    NSPasteboard.PasteboardType("org.nspasteboard.AutoGeneratedType")
                ]
                let isConcealed = pb.types?.contains { type in concealedTypes.contains(type) } ?? false
                if isConcealed {
                    return
                }
                
                if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
                    let names = urls.map { $0.lastPathComponent }.joined(separator: ", ")
                    let item = ClipboardItem(text: names, fileURLs: urls)
                    DispatchQueue.main.async {
                        if !self.clipboardHistory.contains(item) {
                            self.clipboardHistory.insert(item, at: 0)
                            if self.clipboardHistory.count > 15 {
                                self.clipboardHistory.removeLast()
                            }
                        }
                    }
                } else if let str = pb.string(forType: .string),
                          !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let item = ClipboardItem(text: str)
                    DispatchQueue.main.async {
                        if !self.clipboardHistory.contains(item) {
                            self.clipboardHistory.insert(item, at: 0)
                            if self.clipboardHistory.count > 15 {
                                self.clipboardHistory.removeLast()
                            }
                        }
                    }
                }
            }
        }
        RunLoop.main.add(clipTimer, forMode: .common)
        self.clipboardTimer = clipTimer
    }
    
    func triggerChargingBanner(percent: Int) {
        self.batteryPercent = percent
        chargingBannerWorkItem?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            self.showChargingBanner = true
        }
        NSSound(named: "Blow")?.play()
        let item = DispatchWorkItem { [weak self] in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                self?.showChargingBanner = false
            }
        }
        chargingBannerWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2, execute: item)
    }
    
    func openCameraMirror() {
        showSettingsInline = false
        withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
            isCameraMirrorOpen = true
        }
    }
    
    func closeCameraMirror() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            isCameraMirrorOpen = false
        }
        CameraManager.shared.stop()
    }
    
    func toggleCameraMirror() {
        if isCameraMirrorOpen {
            closeCameraMirror()
        } else {
            openCameraMirror()
        }
    }
    
    func copyClipboardItem(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        if item.isFile, let urls = item.fileURLs, !urls.isEmpty {
            pb.writeObjects(urls as [NSURL])
            pb.setString(item.text, forType: .string)
        } else {
            pb.setString(item.text, forType: .string)
        }
        self.lastPasteboardChangeCount = pb.changeCount
        NSSound(named: "Pop")?.play()
    }
    
    func startTimer(seconds: Int) {
        timerPresetDuration = seconds
        timerSecondsRemaining = seconds
        isTimerActive = true
        startTimerCountdown()
    }
    
    func toggleTimer() {
        isTimerActive.toggle()
        if isTimerActive {
            if timerSecondsRemaining <= 0 {
                timerSecondsRemaining = timerPresetDuration
            }
            startTimerCountdown()
        } else {
            pomodoroTimer?.invalidate()
        }
    }
    
    func resetTimer() {
        isTimerActive = false
        pomodoroTimer?.invalidate()
        timerSecondsRemaining = timerPresetDuration
    }
    
    private func startTimerCountdown() {
        pomodoroTimer?.invalidate()
        let pTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.timerSecondsRemaining > 0 {
                self.timerSecondsRemaining -= 1
            } else {
                self.isTimerActive = false
                self.pomodoroTimer?.invalidate()
                NSSound(named: "Glass")?.play()
                DispatchQueue.main.async {
                    self.expand(tab: .timer)
                }
            }
        }
        RunLoop.main.add(pTimer, forMode: .common)
        self.pomodoroTimer = pTimer
    }
    
    func toggleDND() {
        isDNDActive.toggle()
        UserDefaults.standard.set(isDNDActive, forKey: "nb_dnd_active")
        NSSound(named: "Pop")?.play()
        DNDManager.shared.setDND(active: isDNDActive)
    }
    
    func selectTab(_ tab: NotchTab) {
        showSettingsInline = false
        closeCameraMirror()
        guard tab != activeTab else { return }
        slideDirection = tab.index > activeTab.index ? .forward : .backward
        withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
            activeTab = tab
        }
    }
    
    func nextTab() {
        showSettingsInline = false
        closeCameraMirror()
        let all = NotchTab.allCases
        if let curIdx = all.firstIndex(of: activeTab), curIdx + 1 < all.count {
            selectTab(all[curIdx + 1])
        }
    }
    
    func previousTab() {
        showSettingsInline = false
        closeCameraMirror()
        let all = NotchTab.allCases
        if let curIdx = all.firstIndex(of: activeTab), curIdx > 0 {
            selectTab(all[curIdx - 1])
        }
    }
    
    func openClipboard() {
        selectTab(.clipboard)
        if !isExpanded {
            expand(tab: .clipboard)
        }
    }
    
    func openTimer() {
        selectTab(.timer)
        if !isExpanded {
            expand(tab: .timer)
        }
    }
    
    func openTools() {
        openTimer()
    }
    
    func toggleSettingsInline() {
        closeCameraMirror()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            showSettingsInline.toggle()
        }
    }
    
    func expand(tab: NotchTab? = nil) {
        cancelCollapseTimer()
        if isExpanded {
            if let tab = tab {
                selectTab(tab)
            }
            return
        }
        
        withAnimation(.timingCurve(0.16, 1.0, 0.3, 1.0, duration: 0.30)) {
            if let tab = tab {
                self.activeTab = tab
            } else if self.isDragHovering {
                self.activeTab = .shelf
            } else if self.isTimerActive && self.currentTrack == nil {
                self.activeTab = .timer
            } else if self.currentTrack != nil {
                self.activeTab = .music
            } else {
                self.activeTab = .shelf
            }
            self.isExpanded = true
        }
    }
    
    func collapse(immediate: Bool = false) {
        closeCameraMirror()
        if immediate {
            cancelCollapseTimer()
            self.isMouseHovering = false
            self.isDragHovering = false
            withAnimation(.timingCurve(0.16, 1.0, 0.3, 1.0, duration: 0.26)) {
                self.isExpanded = false
            }
            return
        }
        
        cancelCollapseTimer()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if !self.isMouseHovering && !self.isDragHovering {
                withAnimation(.timingCurve(0.16, 1.0, 0.3, 1.0, duration: 0.26)) {
                    self.isExpanded = false
                }
            }
        }
        collapseWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32, execute: item)
    }
    
    func cancelCollapseTimer() {
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
    }
    
    func toggleExpand() {
        if isExpanded {
            collapse(immediate: true)
        } else {
            expand()
        }
    }
    
    func toggleOuterPanel() {
        withAnimation(.easeInOut(duration: 0.22)) {
            isOuterPanelHidden.toggle()
        }
    }
    
    func addFiles(urls: [URL]) {
        for url in urls {
            if !stashedFiles.contains(where: { $0.url == url }) {
                let item = StashedItem(url: url)
                stashedFiles.insert(item, at: 0)
            }
        }
        NSSound(named: "Pop")?.play()
        expand(tab: .shelf)
    }
    
    func removeFile(id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            stashedFiles.removeAll { $0.id == id }
        }
    }
    
    func clearAllFiles() {
        withAnimation(.easeInOut(duration: 0.2)) {
            stashedFiles.removeAll()
        }
    }
    
    func revealInFinder(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    func triggerAirDrop(urls: [URL]) {
        guard !urls.isEmpty else { return }
        if let service = NSSharingService(named: .sendViaAirDrop) {
            service.perform(withItems: urls)
        }
    }
    
    func seekTrack(to position: Double) {
        guard let track = currentTrack else { return }
        let clamped = max(0.0, min(track.duration, position))
        currentTrack?.position = clamped
        MediaController.shared.seek(to: clamped)
    }
    
    func seekTrackBy(seconds: Double) {
        guard let track = currentTrack else { return }
        let newPos = max(0.0, min(track.duration, track.position + seconds))
        seekTrack(to: newPos)
    }
}
