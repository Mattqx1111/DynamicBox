import SwiftUI

struct InlineSettingsView: View {
    @ObservedObject var viewModel: NotchViewModel
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                        Text("Back")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(Color.cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.cyan.opacity(0.15)))
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Text("Notch Preferences")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
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
            .padding(.horizontal, 14)
            .padding(.top, 4)
            
            Divider().background(Color.white.opacity(0.08))
            
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AUDIO WAVEFORM COLOR")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.45))
                    
                    HStack(spacing: 6) {
                        ForEach(WaveColor.allCases) { color in
                            Circle()
                                .fill(color.gradient)
                                .frame(width: 18, height: 18)
                                .overlay(
                                    Circle().stroke(Color.white, lineWidth: viewModel.waveColor == color ? 2 : 0)
                                )
                                .onTapGesture {
                                    withAnimation { viewModel.waveColor = color }
                                }
                        }
                    }
                    
                    Toggle(isOn: Binding(
                        get: { !viewModel.isOuterPanelHidden },
                        set: { viewModel.isOuterPanelHidden = !$0 }
                    )) {
                        Text("Show Outer Island Wings")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .cyan))
                    
                    Toggle(isOn: $viewModel.keepMusicWhenPaused) {
                        Text("Keep Island when Paused")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .cyan))
                    
                    Toggle(isOn: $viewModel.showTimerInNotch) {
                        Text("Show Live Timer in Notch")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .cyan))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("TIMER PRESET DURATION")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.45))
                    
                    HStack(spacing: 4) {
                        ForEach([5, 15, 25, 45, 60], id: \.self) { mins in
                            Button(action: {
                                viewModel.startTimer(seconds: mins * 60)
                            }) {
                                Text("\(mins)m")
                                    .font(.system(size: 9, weight: (viewModel.timerPresetDuration == mins * 60) ? .bold : .regular))
                                    .foregroundColor(viewModel.timerPresetDuration == mins * 60 ? .cyan : .white.opacity(0.75))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2.5)
                                    .background(Capsule().fill(viewModel.timerPresetDuration == mins * 60 ? Color.cyan.opacity(0.25) : Color.white.opacity(0.08)))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    Toggle(isOn: Binding(
                        get: { UserDefaults.standard.object(forKey: "play_sounds") as? Bool ?? true },
                        set: { UserDefaults.standard.set($0, forKey: "play_sounds") }
                    )) {
                        Text("Sound Effects on Drop")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .cyan))
                    
                    HStack {
                        Text("Toggle Hotkey:")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                        Text("⌥ Space")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.white.opacity(0.12)))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 6)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: NotchViewModel
    
    var body: some View {
        Form {
            Section(header: Text("Dynamic Island & Notch").font(.headline)) {
                Toggle("Show Outer Island Wings (Compact Ears)", isOn: Binding(
                    get: { !viewModel.isOuterPanelHidden },
                    set: { viewModel.isOuterPanelHidden = !$0 }
                ))
                
                Toggle("Show Music Cover & Waveform in Compact Notch", isOn: $viewModel.showMusicInNotch)
                
                Toggle("Keep Music Island visible when paused", isOn: $viewModel.keepMusicWhenPaused)
                    .disabled(!viewModel.showMusicInNotch)
                
                Toggle("Show Live Timer in Compact Notch", isOn: $viewModel.showTimerInNotch)
                
                Picker("Audio Waveform Color", selection: $viewModel.waveColor) {
                    ForEach(WaveColor.allCases) { color in
                        HStack {
                            Circle()
                                .fill(color.gradient)
                                .frame(width: 12, height: 12)
                            Text(color.rawValue)
                        }
                        .tag(color)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            Section(header: Text("Timer Presets").font(.headline)) {
                Picker("Default Timer Duration", selection: Binding(
                    get: { viewModel.timerPresetDuration / 60 },
                    set: { viewModel.timerPresetDuration = $0 * 60; viewModel.timerSecondsRemaining = $0 * 60 }
                )) {
                    Text("5 minutes (Short Break)").tag(5)
                    Text("15 minutes (Long Break)").tag(15)
                    Text("25 minutes (Pomodoro Focus)").tag(25)
                    Text("45 minutes (Deep Work)").tag(45)
                    Text("60 minutes (1 Hour)").tag(60)
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            Section(header: Text("Triggers & Behavior").font(.headline)) {
                Toggle("Expand on Mouse Hover", isOn: Binding(
                    get: { UserDefaults.standard.object(forKey: "expand_on_hover") as? Bool ?? true },
                    set: { UserDefaults.standard.set($0, forKey: "expand_on_hover") }
                ))
                
                Toggle("Expand when Dragging Files", isOn: Binding(
                    get: { UserDefaults.standard.object(forKey: "expand_on_drag") as? Bool ?? true },
                    set: { UserDefaults.standard.set($0, forKey: "expand_on_drag") }
                ))
                
                Toggle("Sound Effects on Drop & Actions", isOn: Binding(
                    get: { UserDefaults.standard.object(forKey: "play_sounds") as? Bool ?? true },
                    set: { UserDefaults.standard.set($0, forKey: "play_sounds") }
                ))
                
                Toggle("Launch DynamicBox at Login", isOn: Binding(
                    get: { UserDefaults.standard.object(forKey: "launch_at_login") as? Bool ?? true },
                    set: { UserDefaults.standard.set($0, forKey: "launch_at_login") }
                ))
            }
            
            Section(header: Text("Shortcuts").font(.headline)) {
                HStack {
                    Text("Global Toggle Hotkey")
                    Spacer()
                    Text("⌥ Space")
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.15)))
                }
            }
        }
        .padding(20)
        .frame(width: 460, height: 400)
    }
}
