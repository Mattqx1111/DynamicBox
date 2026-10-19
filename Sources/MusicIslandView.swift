import SwiftUI

struct MusicIslandView: View {
    @ObservedObject var viewModel: NotchViewModel
    
    @State private var isScrubbing: Bool = false
    @State private var scrubProgress: Double = 0.0
    @State private var isHoveringScrubber: Bool = false
    
    var body: some View {
        if let track = viewModel.currentTrack {
            HStack(spacing: 14) {
                ZStack {
                    if let art = track.artwork {
                        Image(nsImage: art)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                            )
                            .shadow(color: .black.opacity(0.5), radius: 4)
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.8), Color.red.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                            )
                    }
                }
                .frame(width: 56, height: 56)
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(track.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(track.playerApp)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.white.opacity(0.1)))
                    }
                    
                    Text(track.artist)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                    
                    let displayedPos = isScrubbing ? (scrubProgress * track.duration) : track.position
                    let displayedRemaining = max(0.0, track.duration - displayedPos)
                    
                    HStack(spacing: 7) {
                        Text(formatTime(displayedPos))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 32, alignment: .leading)
                        
                        GeometryReader { geo in
                            let effectiveProgress = isScrubbing ? scrubProgress : (track.duration > 0 ? min(1.0, max(0.0, track.position / track.duration)) : 0.0)
                            let barHeight: CGFloat = (isHoveringScrubber || isScrubbing) ? 5.5 : 3.5
                            let knobSize: CGFloat = (isHoveringScrubber || isScrubbing) ? 10.0 : 6.0
                            let progressWidth = max(0, min(geo.size.width, geo.size.width * CGFloat(effectiveProgress)))
                            
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.18))
                                    .frame(height: barHeight)
                                
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(red: 1.0, green: 0.65, blue: 0.2), Color(red: 1.0, green: 0.3, blue: 0.2)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: progressWidth, height: barHeight)
                                
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: knobSize, height: knobSize)
                                    .shadow(color: .black.opacity(0.4), radius: 2)
                                    .offset(x: max(0, min(geo.size.width - knobSize, progressWidth - knobSize / 2)))
                            }
                            .frame(height: 18)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { val in
                                        isScrubbing = true
                                        viewModel.isScrubbingTrack = true
                                        let frac = max(0.0, min(1.0, Double(val.location.x / geo.size.width)))
                                        scrubProgress = frac
                                    }
                                    .onEnded { val in
                                        let frac = max(0.0, min(1.0, Double(val.location.x / geo.size.width)))
                                        isScrubbing = false
                                        viewModel.isScrubbingTrack = false
                                        viewModel.seekTrack(to: frac * track.duration)
                                    }
                            )
                        }
                        .frame(height: 18)
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                isHoveringScrubber = hovering
                            }
                        }
                        
                        Text("-\(formatTime(displayedRemaining))")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 36, alignment: .trailing)
                    }
                    .padding(.top, 1)
                    
                    HStack(spacing: 18) {
                        Spacer()
                        
                        Button(action: {
                            viewModel.seekTrackBy(seconds: -15)
                        }) {
                            Image(systemName: "gobackward.15")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.75))
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(Color.white.opacity(0.07)))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Перемотка на 15 сек назад")
                        
                        Button(action: {
                            MediaController.shared.previousTrack()
                        }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.85))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Предыдущий трек")
                        
                        Button(action: {
                            MediaController.shared.playPause()
                            viewModel.currentTrack?.isPlaying.toggle()
                        }) {
                            Image(systemName: track.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(Color.white.opacity(0.18)))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(track.isPlaying ? "Пауза" : "Воспроизведение")
                        
                        Button(action: {
                            MediaController.shared.nextTrack()
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.85))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Следующий трек")
                        
                        Button(action: {
                            viewModel.seekTrackBy(seconds: 15)
                        }) {
                            Image(systemName: "goforward.15")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.75))
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(Color.white.opacity(0.07)))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Перемотка на 15 сек вперед")
                        
                        Spacer()
                    }
                    .padding(.top, 1)
                }
                
                EqualizerView(heights: viewModel.equalizerHeights, isPlaying: track.isPlaying)
                    .frame(width: 32)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

        } else {
            VStack(spacing: 8) {
                Image(systemName: "music.note")
                    .font(.system(size: 22))
                    .foregroundColor(.white.opacity(0.35))
                Text("No Music Playing")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                Text("Open Apple Music or Spotify to control playback")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.45))
                
                Button(action: {
                    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Music") {
                        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                    }
                }) {
                    Text("Open Music")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let s = Int(seconds)
        let m = s / 60
        let sec = s % 60
        return String(format: "%02d:%02d", m, sec)
    }
}

struct EqualizerView: View {
    let heights: [CGFloat]
    let isPlaying: Bool
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<heights.count, id: \.self) { idx in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(
                        LinearGradient(
                            colors: [Color.orange, Color(red: 1.0, green: 0.35, blue: 0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3.2, height: heights[idx])
                    .animation(.linear(duration: 0.12), value: heights[idx])
            }
        }
        .frame(height: 24, alignment: .bottom)
    }
}
