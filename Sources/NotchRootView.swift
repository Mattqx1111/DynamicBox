import SwiftUI

struct NotchRootView: View {
    @ObservedObject var viewModel: NotchViewModel
    
    var body: some View {
        ZStack(alignment: .top) {
            if viewModel.isLiquidGlassEnabled {
                NotchShape(cornerRadius: viewModel.isExpanded ? 22 : 10, isFlushToTop: viewModel.isFlushToTop)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        NotchShape(cornerRadius: viewModel.isExpanded ? 22 : 10, isFlushToTop: viewModel.isFlushToTop)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(white: 0.18, opacity: 0.50),
                                        Color(white: 0.06, opacity: 0.72)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .overlay(
                        NotchShape(cornerRadius: viewModel.isExpanded ? 22 : 10, isFlushToTop: viewModel.isFlushToTop)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.40),
                                        Color.white.opacity(0.16),
                                        Color.white.opacity(0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.0
                            )
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 6)
            } else {
                NotchShape(cornerRadius: viewModel.isExpanded ? 22 : 10, isFlushToTop: viewModel.isFlushToTop)
                    .fill(Color(red: 0, green: 0, blue: 0).opacity(viewModel.isExpanded ? 0.95 : 1.0))
            }
            
            ZStack(alignment: .top) {
                if !viewModel.isExpanded {
                    CompactNotchView(viewModel: viewModel)
                        .frame(height: 32)
                        .transition(.asymmetric(
                            insertion: .opacity.animation(.easeInOut(duration: 0.16)),
                            removal: .opacity.animation(.easeInOut(duration: 0.10))
                        ))
                } else {
                    ExpandedNotchHubView(viewModel: viewModel)
                        .frame(width: 540, height: viewModel.isCameraMirrorOpen ? 340 : (viewModel.showSettingsInline ? 260 : 220))
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: -6)).animation(.easeOut(duration: 0.22).delay(0.06)),
                            removal: .opacity.animation(.easeIn(duration: 0.10))
                        ))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()
        }
        .notchBorder(
            isExpanded: viewModel.isExpanded,
            cornerRadius: viewModel.isExpanded ? 22 : 10,
            isFlushToTop: viewModel.isFlushToTop
        )
    }
}

struct ExpandedNotchHubView: View {
    @ObservedObject var viewModel: NotchViewModel
    
    var notchTopPadding: CGFloat {
        viewModel.isFlushToTop ? 38.0 : 8.0
    }
    
    private var tabTransition: AnyTransition {
        if viewModel.slideDirection == .forward {
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        } else {
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }
    
    var body: some View {
        if viewModel.showSettingsInline {
            InlineSettingsView(viewModel: viewModel, onBack: {
                viewModel.toggleSettingsInline()
            })
            .padding(.top, notchTopPadding)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            ))
        } else if viewModel.isCameraMirrorOpen {
            CameraMirrorView(viewModel: viewModel)
                .padding(.top, notchTopPadding)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.98)),
                    removal: .opacity
                ))
        } else {
            VStack(spacing: 5) {
                HStack(spacing: 0) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9))
                            .foregroundColor(Color.cyan)
                        Text("DynamicBox")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .padding(.leading, 2)
                    
                    Spacer(minLength: 8)
                    
                    HStack(spacing: 2) {
                        ForEach(NotchTab.allCases) { tab in
                            Button(action: {
                                viewModel.selectTab(tab)
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: tab.iconName)
                                        .font(.system(size: 8.5))
                                    Text(tab.rawValue)
                                        .font(.system(size: 9.5, weight: viewModel.activeTab == tab ? .bold : .medium))
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                                .foregroundColor(viewModel.activeTab == tab ? .white : .white.opacity(0.55))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3.5)
                                .background(
                                    Capsule().fill(viewModel.activeTab == tab ? Color.white.opacity(0.2) : Color.clear)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(2)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
                    
                    Spacer(minLength: 8)
                    
                    HStack(spacing: 5) {
                        Button(action: {
                            viewModel.toggleDND()
                        }) {
                            Image(systemName: viewModel.isDNDActive ? "moon.fill" : "moon")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(viewModel.isDNDActive ? Color(red: 0.75, green: 0.55, blue: 1.0) : .white.opacity(0.55))
                                .padding(4)
                                .background(
                                    Circle().fill(viewModel.isDNDActive ? Color(red: 0.75, green: 0.55, blue: 1.0).opacity(0.25) : Color.white.opacity(0.08))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(viewModel.isDNDActive ? "Не беспокоить: Включен (кликните для отключения)" : "Не беспокоить: Выключен (кликните для включения)")
                        
                        Button(action: {
                            viewModel.toggleOuterPanel()
                        }) {
                            Image(systemName: viewModel.isOuterPanelHidden ? "eye.slash.fill" : "eye.fill")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(viewModel.isOuterPanelHidden ? Color.orange : .white.opacity(0.55))
                                .padding(4)
                                .background(
                                    Circle().fill(viewModel.isOuterPanelHidden ? Color.orange.opacity(0.25) : Color.white.opacity(0.08))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(viewModel.isOuterPanelHidden ? "Внешняя панелька скрыта (кликните, чтобы показать)" : "Скрыть внешнюю панельку за челку")
                        
                        Button(action: {
                            viewModel.toggleCameraMirror()
                        }) {
                            Image(systemName: viewModel.isCameraMirrorOpen ? "camera.fill" : "camera")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(viewModel.isCameraMirrorOpen ? Color.green : .white.opacity(0.55))
                                .padding(4)
                                .background(
                                    Circle().fill(viewModel.isCameraMirrorOpen ? Color.green.opacity(0.25) : Color.white.opacity(0.08))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(viewModel.isCameraMirrorOpen ? "Закрыть зеркало камеры" : "Быстрое зеркало / превью камеры")
                        
                        Button(action: {
                            viewModel.toggleSettingsInline()
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(viewModel.showSettingsInline ? Color.cyan : .white.opacity(0.55))
                                .padding(4)
                                .background(Circle().fill(viewModel.showSettingsInline ? Color.cyan.opacity(0.2) : Color.white.opacity(0.08)))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Preferences inside Notch")
                        
                        Button(action: {
                            viewModel.collapse(immediate: true)
                        }) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white.opacity(0.55))
                                .padding(4)
                                .background(Circle().fill(Color.white.opacity(0.08)))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, notchTopPadding)
                
                Divider()
                    .background(Color.white.opacity(0.08))
                    .padding(.horizontal, 10)
                
                ZStack {
                    switch viewModel.activeTab {
                    case .music:
                        MusicIslandView(viewModel: viewModel)
                            .transition(tabTransition)
                            .id(NotchTab.music)
                    case .shelf:
                        FileShelfView(viewModel: viewModel)
                            .transition(tabTransition)
                            .id(NotchTab.shelf)
                    case .notes:
                        NotesTabView(viewModel: viewModel)
                            .transition(tabTransition)
                            .id(NotchTab.notes)
                    case .clipboard:
                        ClipboardTabView(viewModel: viewModel)
                            .transition(tabTransition)
                            .id(NotchTab.clipboard)
                    case .timer:
                        TimerTabView(viewModel: viewModel)
                            .transition(tabTransition)
                            .id(NotchTab.timer)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            if value.translation.width < -25 {
                                viewModel.nextTab()
                            } else if value.translation.width > 25 {
                                viewModel.previousTab()
                            }
                        }
                )
                
                HStack(spacing: 5) {
                    ForEach(NotchTab.allCases) { tab in
                        Circle()
                            .fill(viewModel.activeTab == tab ? Color.white.opacity(0.9) : Color.white.opacity(0.2))
                            .frame(width: viewModel.activeTab == tab ? 5.5 : 3.5, height: viewModel.activeTab == tab ? 5.5 : 3.5)
                            .onTapGesture {
                                viewModel.selectTab(tab)
                            }
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }
}

struct CompactNotchView: View {
    @ObservedObject var viewModel: NotchViewModel
    
    var showMusic: Bool {
        if viewModel.isFullScreenActive || viewModel.isOuterPanelHidden { return false }
        guard viewModel.showMusicInNotch, let track = viewModel.currentTrack else { return false }
        return track.isPlaying || viewModel.keepMusicWhenPaused
    }
    
    var showTimer: Bool {
        if viewModel.isFullScreenActive || viewModel.isOuterPanelHidden { return false }
        return viewModel.showTimerInNotch && viewModel.isTimerActive
    }
    
    var showShelf: Bool {
        if viewModel.isFullScreenActive || viewModel.isOuterPanelHidden { return false }
        return !viewModel.stashedFiles.isEmpty
    }
    
    @ViewBuilder
    private var leftEarView: some View {
        HStack(spacing: 0) {
            if showMusic, let track = viewModel.currentTrack {
                if let art = track.artwork {
                    Image(nsImage: art)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 22, height: 22)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.55, blue: 0.2), Color(red: 0.95, green: 0.2, blue: 0.35)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 22, height: 22)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
            } else if showTimer {
                Image(systemName: "timer")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.cyan)
            } else if showShelf {
                HStack(spacing: 3) {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 9))
                    Text("\(viewModel.stashedFiles.count)")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(Color(red: 0.19, green: 0.82, blue: 0.35))
            }
        }
        .frame(width: 68, alignment: .leading)
        .padding(.leading, 10)
    }
    
    @ViewBuilder
    private var rightEarView: some View {
        HStack(spacing: 0) {
            if showTimer && (!showMusic || !viewModel.currentTrack!.isPlaying) {
                Text(viewModel.timerString)
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.cyan)
            } else if showMusic, let track = viewModel.currentTrack {
                AnimatedSoundWaveView(
                    heights: viewModel.equalizerHeights,
                    isPlaying: track.isPlaying,
                    waveColor: viewModel.waveColor
                )
            } else if showTimer {
                Text(viewModel.timerString)
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.cyan)
            } else if showShelf {
                Image(systemName: "chevron.compact.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .frame(width: 68, alignment: .trailing)
        .padding(.trailing, 10)
    }
    
    @ViewBuilder
    private var combinedSingleEarView: some View {
        HStack(spacing: 5) {
            if showMusic, let track = viewModel.currentTrack {
                if let art = track.artwork {
                    Image(nsImage: art)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 18, height: 18)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.55, blue: 0.2), Color(red: 0.95, green: 0.2, blue: 0.35)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 18, height: 18)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                AnimatedSoundWaveView(
                    heights: viewModel.equalizerHeights,
                    isPlaying: track.isPlaying,
                    waveColor: viewModel.waveColor
                )
            } else if showTimer {
                Image(systemName: "timer")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.cyan)
                Text(viewModel.timerString)
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.cyan)
            } else if showShelf {
                Image(systemName: "tray.fill")
                    .font(.system(size: 9))
                    .foregroundColor(Color(red: 0.19, green: 0.82, blue: 0.35))
                Text("\(viewModel.stashedFiles.count)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(red: 0.19, green: 0.82, blue: 0.35))
            }
        }
    }
    
    var body: some View {
        if viewModel.showChargingBanner {
            HStack(spacing: 0) {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.4))
                    Text("Зарядка")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 80, alignment: .leading)
                .padding(.leading, 12)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("\(viewModel.batteryPercent)%")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.4))
                    Image(systemName: viewModel.batteryPercent >= 90 ? "battery.100.bolt" : (viewModel.batteryPercent >= 50 ? "battery.75" : "battery.25"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.4))
                }
                .frame(width: 80, alignment: .trailing)
                .padding(.trailing, 12)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .transition(.asymmetric(
                insertion: .scale(scale: 0.92).combined(with: .opacity),
                removal: .opacity
            ))
            .onTapGesture {
                viewModel.expand()
            }
        } else if showMusic || showTimer || showShelf {
            Group {
                switch viewModel.wingMode {
                case .symmetric:
                    HStack(spacing: 0) {
                        leftEarView
                        Spacer().frame(width: 174)
                        rightEarView
                    }
                case .rightOnly:
                    HStack(spacing: 0) {
                        Spacer().frame(width: 174)
                        combinedSingleEarView
                            .frame(width: 68, alignment: .trailing)
                            .padding(.trailing, 10)
                    }
                case .leftOnly:
                    HStack(spacing: 0) {
                        combinedSingleEarView
                            .frame(width: 68, alignment: .leading)
                            .padding(.leading, 10)
                        Spacer().frame(width: 174)
                    }
                case .flush:
                    Color.clear
                        .frame(width: 174, height: 32)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 15)
                    .onEnded { val in
                        if val.translation.width < -15 {
                            viewModel.openTimer()
                        } else if val.translation.width > 15 {
                            viewModel.expand(tab: .music)
                        }
                    }
            )
            .onTapGesture {
                viewModel.expand()
            }
        } else {
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 15)
                        .onEnded { val in
                            if val.translation.width < -15 {
                                viewModel.openTimer()
                            }
                        }
                )
                .onTapGesture {
                    viewModel.expand()
                }
        }
    }
}

struct AnimatedSoundWaveView: View {
    let heights: [CGFloat]
    let isPlaying: Bool
    var waveColor: WaveColor = .orange
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 2.2) {
            ForEach(0..<4, id: \.self) { idx in
                let rawH = (idx < heights.count) ? heights[idx] : 8.0
                let h = isPlaying ? max(3.5, rawH * 0.75) : 3.5
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(waveColor.gradient)
                    .frame(width: 2.8, height: h)
                    .animation(.easeInOut(duration: 0.12), value: h)
            }
        }
        .frame(height: 18, alignment: .bottom)
    }
}
