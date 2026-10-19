import SwiftUI

struct NotesTabView: View {
    @ObservedObject var viewModel: NotchViewModel
    @State private var isCopied: Bool = false
    
    var wordCount: Int {
        let trimmed = viewModel.quickNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return 0 }
        return trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
    
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Label("SCRATCHPAD", systemImage: "note.text")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                
                Text("\(wordCount) words")
                    .font(.system(size: 9.5))
                    .foregroundColor(.white.opacity(0.45))
                
                Spacer()
                
                if !viewModel.quickNotes.isEmpty {
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(viewModel.quickNotes, forType: .string)
                        isCopied = true
                        NSSound(named: "Pop")?.play()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            isCopied = false
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 8.5, weight: .bold))
                            Text(isCopied ? "Copied!" : "Copy")
                                .font(.system(size: 9.5, weight: .medium))
                        }
                        .foregroundColor(isCopied ? Color.green : .white.opacity(0.7))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        withAnimation {
                            viewModel.quickNotes = ""
                        }
                    }) {
                        Text("Clear")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(.white.opacity(0.55))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)
            
            ZStack(alignment: .topLeading) {
                if viewModel.quickNotes.isEmpty {
                    Text("Type quick notes, scratchpad, ideas, or to-dos here...\nAuto-saves automatically.")
                        .font(.system(size: 11.5))
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }
                
                TextEditor(text: $viewModel.quickNotes)
                    .font(.system(size: 11.5))
                    .foregroundColor(.white.opacity(0.95))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
    }
}
