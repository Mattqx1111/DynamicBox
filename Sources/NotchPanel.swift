import Cocoa
import SwiftUI
import Combine

class NotchDropHostView<Content: View>: NSHostingView<Content> {
    weak var viewModel: NotchViewModel?
    private var hasSwipedInCurrentGesture: Bool = false
    private var lastDiscreteScrollTime: Date = Date.distantPast
    
    init(rootView: Content, viewModel: NotchViewModel) {
        self.viewModel = viewModel
        super.init(rootView: rootView)
        registerForDraggedTypes([.fileURL])
    }
    
    @MainActor required dynamic init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @MainActor required dynamic init(rootView: Content) {
        super.init(rootView: rootView)
        registerForDraggedTypes([.fileURL])
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    override func scrollWheel(with event: NSEvent) {
        if event.phase == .began {
            hasSwipedInCurrentGesture = false
            return
        }
        
        if event.phase == .ended || event.phase == .cancelled {
            hasSwipedInCurrentGesture = false
            return
        }
        
        if event.momentumPhase != [] {
            return
        }
        
        if event.phase == .changed {
            if !hasSwipedInCurrentGesture && abs(event.scrollingDeltaX) > 12 {
                hasSwipedInCurrentGesture = true
                if event.scrollingDeltaX < -12 {
                    viewModel?.nextTab()
                } else if event.scrollingDeltaX > 12 {
                    viewModel?.previousTab()
                }
            }
            return
        }
        
        if event.phase == [] {
            let now = Date()
            if now.timeIntervalSince(lastDiscreteScrollTime) > 0.6 && abs(event.scrollingDeltaX) > 15 {
                lastDiscreteScrollTime = now
                if event.scrollingDeltaX < -15 {
                    viewModel?.nextTab()
                } else if event.scrollingDeltaX > 15 {
                    viewModel?.previousTab()
                }
            }
            return
        }
        
        super.scrollWheel(with: event)
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pboard = sender.draggingPasteboard
        guard pboard.canReadItem(withDataConformingToTypes: [NSPasteboard.PasteboardType.fileURL.rawValue]) else {
            return []
        }
        
        updateDragTarget(sender)
        viewModel?.isDragHovering = true
        viewModel?.expand(tab: .shelf)
        return .copy
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        updateDragTarget(sender)
        return .copy
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        viewModel?.dragHoverTarget = .none
        viewModel?.isDragHovering = false
        viewModel?.collapse()
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let loc = sender.draggingLocation
        let isAirDrop = (loc.x >= bounds.width - 165 && loc.y <= bounds.height - 35)
        
        viewModel?.isDragHovering = false
        viewModel?.dragHoverTarget = .none
        
        let pboard = sender.draggingPasteboard
        guard let items = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !items.isEmpty else {
            return false
        }
        
        if isAirDrop {
            viewModel?.triggerAirDrop(urls: items)
        } else {
            viewModel?.addFiles(urls: items)
        }
        return true
    }
    
    private func updateDragTarget(_ sender: NSDraggingInfo) {
        let loc = sender.draggingLocation
        let isAirDrop = (loc.x >= bounds.width - 165 && loc.y <= bounds.height - 35)
        viewModel?.dragHoverTarget = isAirDrop ? .airdrop : .shelf
    }
}

class NotchPanel: NSPanel {
    let viewModel: NotchViewModel
    private var cancellables = Set<AnyCancellable>()
    private var hoverTimer: DispatchSourceTimer?
    private var periodicCheckTimer: Timer?
    
    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 180, height: 32),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.level = .popUpMenu
        self.isOpaque = false
        self.backgroundColor = NSColor(calibratedWhite: 0, alpha: 0.0)
        self.hasShadow = false
        self.isMovable = false
        self.isReleasedWhenClosed = false
        self.hidesOnDeactivate = false
        self.acceptsMouseMovedEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        self.registerForDraggedTypes([.fileURL])
        
        let rootView = NotchRootView(viewModel: viewModel)
        let hostView = NotchDropHostView(rootView: rootView, viewModel: viewModel)
        self.contentView = hostView
        
        setupSubscriptions()
        startHoverMonitoring()
        reposition(animated: false)
        orderFrontRegardless()
        
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.viewModel.collapse(immediate: true)
            self?.viewModel.isMouseHovering = false
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main else { return }
            self.updateFullScreenAndWingMode(on: screen)
        }
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return false
    }
    
    private func startHoverMonitoring() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(35))
        timer.setEventHandler { [weak self] in
            self?.checkHoverState()
        }
        timer.resume()
        self.hoverTimer = timer
        
        let pTimer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self = self, let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main else { return }
            self.updateFullScreenAndWingMode(on: screen)
        }
        RunLoop.main.add(pTimer, forMode: .common)
        self.periodicCheckTimer = pTimer
    }
    
    func updateFullScreenAndWingMode(on screen: NSScreen) {
        let isFS = detectFullScreen(on: screen)
        if viewModel.isFullScreenActive != isFS {
            viewModel.isFullScreenActive = isFS
            if !viewModel.isExpanded {
                reposition(animated: true)
            }
        }
        
        let newWingMode = evaluateWingMode(on: screen)
        if viewModel.wingMode != newWingMode {
            viewModel.wingMode = newWingMode
            viewModel.isMenuCrowded = (newWingMode != .symmetric)
            if !viewModel.isExpanded {
                reposition(animated: true)
            }
        }
    }
    
    private func checkHoverState() {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main else { return }
        
        if !self.isVisible || !self.occlusionState.contains(.visible) {
            if viewModel.isExpanded {
                viewModel.collapse(immediate: true)
            }
            viewModel.isMouseHovering = false
            return
        }
        
        let mouseLoc = NSEvent.mouseLocation
        let screenFrame = screen.frame
        let midX = screenFrame.midX
        let topY = screenFrame.maxY
        
        if !viewModel.isExpanded {
            if !viewModel.isFullScreenActive {
                let notchLeft: CGFloat = screen.auxiliaryTopLeftArea?.width ?? ((screenFrame.width - 180.0) / 2.0)
                let notchRight: CGFloat = screen.auxiliaryTopRightArea?.origin.x ?? (notchLeft + 180.0)
                let notchBaseWidth: CGFloat = notchRight - notchLeft
                let earWidth: CGFloat = 68.0
                
                let currentTargetX: CGFloat
                let currentWidth: CGFloat
                
                if viewModel.isOuterPanelHidden {
                    currentTargetX = notchLeft
                    currentWidth = notchBaseWidth
                } else {
                    switch viewModel.wingMode {
                    case .symmetric:
                        currentTargetX = notchLeft - earWidth
                        currentWidth = notchBaseWidth + earWidth * 2
                    case .rightOnly:
                        currentTargetX = notchLeft
                        currentWidth = notchBaseWidth + earWidth
                    case .leftOnly:
                        currentTargetX = notchLeft - earWidth
                        currentWidth = notchBaseWidth + earWidth
                    case .flush:
                        currentTargetX = notchLeft
                        currentWidth = notchBaseWidth
                    }
                }
                
                let isNearNotch = (mouseLoc.y >= topY - 45) &&
                                  (mouseLoc.y <= topY + 5) &&
                                  (mouseLoc.x >= currentTargetX - 6) &&
                                  (mouseLoc.x <= currentTargetX + currentWidth + 6)
                
                if isNearNotch {
                    if !viewModel.isMouseHovering {
                        viewModel.isMouseHovering = true
                        viewModel.expand()
                    }
                }
            }
        } else {
            let expandedWidth: CGFloat = 550
            let expandedHeight: CGFloat = viewModel.isCameraMirrorOpen ? 340 : 235
            let isInsideExpanded = (mouseLoc.y >= topY - expandedHeight) &&
                                   (mouseLoc.y <= topY + 15) &&
                                   (mouseLoc.x >= midX - expandedWidth / 2) &&
                                   (mouseLoc.x <= midX + expandedWidth / 2)
            
            if isInsideExpanded {
                viewModel.isMouseHovering = true
                viewModel.cancelCollapseTimer()
            } else {
                if viewModel.isMouseHovering {
                    viewModel.isMouseHovering = false
                    viewModel.collapse()
                }
            }
        }
    }

    private func evaluateWingMode(on screen: NSScreen) -> NotchWingMode {
        let screenFrame = screen.frame
        let notchLeft: CGFloat = screen.auxiliaryTopLeftArea?.width ?? ((screenFrame.width - 180.0) / 2.0)
        let notchRight: CGFloat = screen.auxiliaryTopRightArea?.origin.x ?? (notchLeft + 180.0)
        
        var statusItemsMinX: CGFloat = screenFrame.width
        if let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] {
            for w in windowList {
                guard let layer = w[kCGWindowLayer as String] as? Int, layer == 25 else { continue }
                guard let bounds = w[kCGWindowBounds as String] as? [String: Any],
                      let x = bounds["X"] as? CGFloat,
                      let wW = bounds["Width"] as? CGFloat,
                      let y = bounds["Y"] as? CGFloat,
                      let h = bounds["Height"] as? CGFloat else { continue }
                if y <= 10 && h <= 40 && x > screenFrame.width / 2 && wW > 0 && wW < screenFrame.width * 0.8 {
                    statusItemsMinX = min(statusItemsMinX, x)
                }
            }
        }
        
        var leftMenuMaxX: CGFloat = 0
        var rightMenuMinX: CGFloat = screenFrame.width
        
        if let app = NSWorkspace.shared.frontmostApplication, app.bundleIdentifier != "com.dynamicbox.app" {
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            var menuBarValue: AnyObject?
            if AXUIElementCopyAttributeValue(axApp, kAXMenuBarAttribute as CFString, &menuBarValue) == .success {
                let menuBar = menuBarValue as! AXUIElement
                var childrenValue: AnyObject?
                if AXUIElementCopyAttributeValue(menuBar, kAXChildrenAttribute as CFString, &childrenValue) == .success,
                   let children = childrenValue as? [AXUIElement] {
                    for item in children {
                        var posValue: AnyObject?
                        var sizeValue: AnyObject?
                        AXUIElementCopyAttributeValue(item, kAXPositionAttribute as CFString, &posValue)
                        AXUIElementCopyAttributeValue(item, kAXSizeAttribute as CFString, &sizeValue)
                        var pos = CGPoint.zero
                        var size = CGSize.zero
                        if let p = posValue as! AXValue?, AXValueGetValue(p, .cgPoint, &pos),
                           let s = sizeValue as! AXValue?, AXValueGetValue(s, .cgSize, &size) {
                            if pos.x < notchLeft {
                                leftMenuMaxX = max(leftMenuMaxX, pos.x + size.width)
                            } else if pos.x >= notchRight {
                                rightMenuMinX = min(rightMenuMinX, pos.x)
                            }
                        }
                    }
                }
            }
        }
        
        let safeLeft = notchLeft - leftMenuMaxX
        let rightBoundary = min(statusItemsMinX, rightMenuMinX)
        let safeRight = rightBoundary - notchRight
        
        let isCurrentlySymmetric = (viewModel.wingMode == .symmetric)
        let leftThreshold: CGFloat = isCurrentlySymmetric ? 60.0 : 74.0
        let rightThreshold: CGFloat = isCurrentlySymmetric ? 60.0 : 74.0
        
        let leftIsSafe = safeLeft >= leftThreshold
        let rightIsSafe = safeRight >= rightThreshold
        
        if leftIsSafe && rightIsSafe {
            return .symmetric
        } else if !leftIsSafe && rightIsSafe {
            return .rightOnly
        } else if leftIsSafe && !rightIsSafe {
            return .leftOnly
        } else {
            return .flush
        }
    }

    private func detectFullScreen(on screen: NSScreen) -> Bool {
        let screenFrame = screen.frame
        
        let isMenuBarHidden = (screen.visibleFrame.maxY >= screenFrame.maxY - 1.0)
        if isMenuBarHidden {
            return true
        }
        
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        
        for w in windowList {
            guard let layer = w[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let owner = w[kCGWindowOwnerName as String] as? String,
                  !owner.contains("DynamicBox"), !owner.contains("NotchBox") else { continue }
            guard let boundsDict = w[kCGWindowBounds as String] as? [String: Any],
                  let wX = boundsDict["X"] as? CGFloat,
                  let wY = boundsDict["Y"] as? CGFloat,
                  let wW = boundsDict["Width"] as? CGFloat,
                  let wH = boundsDict["Height"] as? CGFloat else { continue }
            
            if wY <= 2.0 && wX <= 2.0 && wW >= screenFrame.width - 4.0 && wH >= screenFrame.height - 4.0 {
                return true
            }
        }
        
        return false
    }
    
    private func setupSubscriptions() {
        viewModel.$isExpanded
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reposition(animated: true)
            }
            .store(in: &cancellables)
            
        viewModel.$isFullScreenActive
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                if self?.viewModel.isExpanded == false {
                    self?.reposition(animated: true)
                }
            }
            .store(in: &cancellables)
            
        viewModel.$isOuterPanelHidden
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                if self?.viewModel.isExpanded == false {
                    self?.reposition(animated: true)
                }
            }
            .store(in: &cancellables)
            
        viewModel.$wingMode
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                if self?.viewModel.isExpanded == false {
                    self?.reposition(animated: true)
                }
            }
            .store(in: &cancellables)
            
        viewModel.$currentTrack
            .map { [weak self] track in
                track != nil && (track!.isPlaying || (self?.viewModel.keepMusicWhenPaused ?? true))
            }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                if self?.viewModel.isExpanded == false {
                    self?.reposition(animated: true)
                }
            }
            .store(in: &cancellables)
            
        viewModel.$isTimerActive
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                if self?.viewModel.isExpanded == false {
                    self?.reposition(animated: true)
                }
            }
            .store(in: &cancellables)
            
        viewModel.$stashedFiles
            .map { !$0.isEmpty }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                if self?.viewModel.isExpanded == false {
                    self?.reposition(animated: true)
                }
            }
            .store(in: &cancellables)
            
        viewModel.$showMusicInNotch
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                if self?.viewModel.isExpanded == false {
                    self?.reposition(animated: true)
                }
            }
            .store(in: &cancellables)
            
        viewModel.$keepMusicWhenPaused
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                if self?.viewModel.isExpanded == false {
                    self?.reposition(animated: true)
                }
            }
            .store(in: &cancellables)
            
        viewModel.$showChargingBanner
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                if self?.viewModel.isExpanded == false {
                    self?.reposition(animated: true)
                }
            }
            .store(in: &cancellables)
            
        viewModel.$isCameraMirrorOpen
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reposition(animated: true)
            }
            .store(in: &cancellables)
    }
    
    func reposition(animated: Bool = true) {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main else { return }
        
        let screenFrame = screen.frame
        let hasNotch = screen.safeAreaInsets.top > 0
        viewModel.isFlushToTop = hasNotch
        
        let notchBaseHeight = hasNotch ? screen.safeAreaInsets.top : 28.0
        let notchLeft: CGFloat = screen.auxiliaryTopLeftArea?.width ?? ((screenFrame.width - 180.0) / 2.0)
        let notchRight: CGFloat = screen.auxiliaryTopRightArea?.origin.x ?? (notchLeft + 180.0)
        let notchBaseWidth: CGFloat = notchRight - notchLeft
        let earWidth: CGFloat = 68.0
        
        let showMusic = !viewModel.isFullScreenActive && !viewModel.isOuterPanelHidden && viewModel.showMusicInNotch && (viewModel.currentTrack != nil) && (viewModel.currentTrack!.isPlaying || viewModel.keepMusicWhenPaused)
        let showTimer = !viewModel.isFullScreenActive && !viewModel.isOuterPanelHidden && viewModel.showTimerInNotch && viewModel.isTimerActive
        let showShelf = !viewModel.isFullScreenActive && !viewModel.isOuterPanelHidden && !viewModel.stashedFiles.isEmpty
        let showCharging = !viewModel.isFullScreenActive && viewModel.showChargingBanner
        let hasActiveContent = showMusic || showTimer || showShelf || showCharging
        
        let compactHeight: CGFloat = notchBaseHeight
        let compactWidth: CGFloat
        let targetX: CGFloat
        
        if (viewModel.isFullScreenActive || viewModel.isOuterPanelHidden) && !viewModel.isExpanded && !showCharging {
            compactWidth = notchBaseWidth
            targetX = notchLeft
        } else if showCharging && !viewModel.isExpanded {
            compactWidth = notchBaseWidth + earWidth * 2.0
            targetX = notchLeft - earWidth
        } else if hasActiveContent {
            switch viewModel.wingMode {
            case .symmetric:
                compactWidth = notchBaseWidth + earWidth * 2.0
                targetX = notchLeft - earWidth
            case .rightOnly:
                compactWidth = notchBaseWidth + earWidth
                targetX = notchLeft
            case .leftOnly:
                compactWidth = notchBaseWidth + earWidth
                targetX = notchLeft - earWidth
            case .flush:
                compactWidth = notchBaseWidth
                targetX = notchLeft
            }
        } else {
            compactWidth = notchBaseWidth
            targetX = notchLeft
        }
        
        let expandedWidth: CGFloat = 520
        let expandedHeight: CGFloat = viewModel.isCameraMirrorOpen ? 340 : 215
        
        let targetWidth = viewModel.isExpanded ? expandedWidth : compactWidth
        let targetHeight = viewModel.isExpanded ? expandedHeight : compactHeight
        
        let x = viewModel.isExpanded ? (screenFrame.origin.x + (screenFrame.width - expandedWidth) / 2.0) : targetX
        let y = screenFrame.origin.y + screenFrame.height - targetHeight
        
        let newFrame = NSRect(x: x, y: y, width: targetWidth, height: targetHeight)
        
        if abs(self.frame.origin.x - newFrame.origin.x) < 0.5 &&
           abs(self.frame.origin.y - newFrame.origin.y) < 0.5 &&
           abs(self.frame.size.width - newFrame.size.width) < 0.5 &&
           abs(self.frame.size.height - newFrame.size.height) < 0.5 {
            return
        }
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
                context.allowsImplicitAnimation = true
                self.animator().setFrame(newFrame, display: true)
            }
        } else {
            self.setFrame(newFrame, display: true)
        }
        self.orderFrontRegardless()
    }
}
