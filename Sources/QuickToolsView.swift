import SwiftUI

struct ClipboardTabView: View {
    @ObservedObject var viewModel: NotchViewModel
    @State private var copiedIdx: Int? = nil
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label("\(viewModel.clipboardHistory.count) COPIED ITEMS", systemImage: "doc.on.clipboard.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                
                Spacer()
                
                if !viewModel.clipboardHistory.isEmpty {
                    Button(action: {
                        withAnimation { viewModel.clipboardHistory.removeAll() }
                    }) {
                        Text("Clear History")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)
            
            if viewModel.clipboardHistory.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.35))
                    Text("Clipboard is empty")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                    Text("Copy any text in any app (⌘C) to stash it here automatically")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.45))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 10)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(viewModel.clipboardHistory.enumerated()), id: \.offset) { idx, item in
                            ClipboardCardView(
                                item: item,
                                isCopied: copiedIdx == idx,
                                onCopy: {
                                    viewModel.copyClipboardItem(item)
                                    copiedIdx = idx
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                        if copiedIdx == idx { copiedIdx = nil }
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
                }
            }
        }
    }
}

struct ClipboardCardView: View {
    let item: ClipboardItem
    let isCopied: Bool
    let onCopy: () -> Void
    
    @State private var isHovered: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                if item.isFile {
                    if let icon = item.fileIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 13, height: 13)
                    } else {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color.orange)
                    }
                    if let ext = item.fileExtension {
                        Text(ext)
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundColor(Color.orange)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.orange.opacity(0.2)))
                    }
                } else {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color.cyan)
                }
                
                Spacer()
                
                if isCopied {
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                        Text(item.isFile ? "File Copied!" : "Copied!")
                            .font(.system(size: 8.5, weight: .bold))
                    }
                    .foregroundColor(Color.green)
                } else {
                    Text(item.isFile ? "Copy file" : "Copy text")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(isHovered ? 0.8 : 0.4))
                }
            }
            
            Text(item.text)
                .font(.system(size: 10.5, weight: item.isFile ? .medium : .regular))
                .foregroundColor(.white.opacity(0.92))
                .lineLimit(3)
                .frame(width: 140, height: 42, alignment: .topLeading)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isCopied ? Color.green.opacity(0.15) : (isHovered ? Color.white.opacity(0.12) : Color.white.opacity(0.06)))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isCopied ? Color.green.opacity(0.4) : (isHovered ? Color.white.opacity(0.25) : Color.white.opacity(0.1)), lineWidth: 1)
                )
        )
        .onHover { isHovered = $0 }
        .onTapGesture {
            onCopy()
        }
    }
}

struct TimerTabView: View {
    @ObservedObject var viewModel: NotchViewModel
    let presets = [5, 15, 25, 45, 60]
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.timerString)
                        .font(.system(size: 30, weight: .bold, design: .monospaced))
                        .foregroundColor(viewModel.isTimerActive ? Color.cyan : .white)
                    
                    Text(viewModel.isTimerActive ? "Active in Dynamic Notch Island" : "Ready • Select preset or press Start")
                        .font(.system(size: 9.5))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                HStack(spacing: 10) {
                    Button(action: {
                        viewModel.toggleTimer()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: viewModel.isTimerActive ? "pause.fill" : "play.fill")
                                .font(.system(size: 10))
                            Text(viewModel.isTimerActive ? "Pause" : "Start")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white))
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        viewModel.resetTimer()
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(6)
                            .background(Circle().fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)
            
            HStack(spacing: 6) {
                ForEach(presets, id: \.self) { mins in
                    Button(action: {
                        viewModel.startTimer(seconds: mins * 60)
                    }) {
                        Text("\(mins)m")
                            .font(.system(size: 10, weight: (viewModel.timerPresetDuration == mins * 60) ? .bold : .regular))
                            .foregroundColor((viewModel.timerPresetDuration == mins * 60 && viewModel.isTimerActive) ? Color.cyan : .white.opacity(0.75))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(
                                    (viewModel.timerPresetDuration == mins * 60 && viewModel.isTimerActive)
                                    ? Color.cyan.opacity(0.2)
                                    : Color.white.opacity(0.08)
                                )
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                Spacer()
                
                Button(action: {
                    viewModel.toggleDND()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.isDNDActive ? "moon.fill" : "moon")
                            .font(.system(size: 9.5, weight: .bold))
                        Text(viewModel.isDNDActive ? "DND On" : "Не беспокоить")
                            .font(.system(size: 9.5, weight: .semibold))
                    }
                    .foregroundColor(viewModel.isDNDActive ? Color(red: 0.8, green: 0.6, blue: 1.0) : .white.opacity(0.75))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3.5)
                    .background(
                        Capsule().fill(
                            viewModel.isDNDActive
                            ? Color(red: 0.72, green: 0.52, blue: 1.0).opacity(0.25)
                            : Color.white.opacity(0.08)
                        )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .help("Включить/выключить режим Не беспокоить")
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 6)
        }
    }
}
