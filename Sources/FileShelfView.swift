import SwiftUI

struct FileShelfView: View {
    @ObservedObject var viewModel: NotchViewModel
    @State private var isAirDropHovered: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label("\(viewModel.stashedFiles.count) FILES", systemImage: "tray.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                
                Spacer()
                
                Button(action: {
                    let urls = viewModel.stashedFiles.map { $0.url }
                    viewModel.triggerAirDrop(urls: urls)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 11, weight: .semibold))
                        Text("AirDrop All")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(isAirDropHovered ? .black : Color(red: 0.2, green: 0.8, blue: 1.0))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(isAirDropHovered ? Color(red: 0.2, green: 0.8, blue: 1.0) : Color.white.opacity(0.08))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { isAirDropHovered = $0 }
                .disabled(viewModel.stashedFiles.isEmpty)
                
                if !viewModel.stashedFiles.isEmpty {
                    Button(action: {
                        viewModel.clearAllFiles()
                    }) {
                        Text("Clear")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)
            
            if viewModel.stashedFiles.isEmpty {
                HStack(spacing: 16) {
                    VStack(spacing: 6) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 24))
                            .foregroundColor(viewModel.dragHoverTarget == .shelf ? Color.green : Color(red: 0.19, green: 0.82, blue: 0.35))
                        Text(viewModel.dragHoverTarget == .shelf ? "Release to stash files" : "Drag files here to stash")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                        Text("Hold files temporarily, drag out to any app")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                viewModel.dragHoverTarget == .shelf ? Color.green : Color.white.opacity(0.12),
                                style: StrokeStyle(lineWidth: viewModel.dragHoverTarget == .shelf ? 2 : 1, dash: [5, 4])
                            )
                            .background(viewModel.dragHoverTarget == .shelf ? Color.green.opacity(0.12) : Color.white.opacity(0.03))
                    )
                    .scaleEffect(viewModel.dragHoverTarget == .shelf ? 1.02 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: viewModel.dragHoverTarget)
                    
                    VStack(spacing: 6) {
                        Image(systemName: "airdrop")
                            .font(.system(size: 24))
                            .foregroundColor(Color(red: 0.04, green: 0.52, blue: 1.0))
                        Text(viewModel.dragHoverTarget == .airdrop ? "Release to AirDrop" : "Drop for AirDrop")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                        Text("Share instantly via macOS AirDrop")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .frame(width: 140)
                    .frame(maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                viewModel.dragHoverTarget == .airdrop ? Color.blue : Color(red: 0.04, green: 0.52, blue: 1.0).opacity(0.4),
                                style: StrokeStyle(lineWidth: viewModel.dragHoverTarget == .airdrop ? 2 : 1, dash: [5, 4])
                            )
                            .background(viewModel.dragHoverTarget == .airdrop ? Color.blue.opacity(0.18) : Color.white.opacity(0.03))
                    )
                    .scaleEffect(viewModel.dragHoverTarget == .airdrop ? 1.02 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: viewModel.dragHoverTarget)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.stashedFiles) { item in
                            FileCardView(item: item, onRemove: {
                                viewModel.removeFile(id: item.id)
                            }, onAirDrop: {
                                viewModel.triggerAirDrop(urls: [item.url])
                            })
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
                }
            }
        }
    }
}

struct FileCardView: View {
    let item: StashedItem
    let onRemove: () -> Void
    let onAirDrop: () -> Void
    
    @State private var isHovered: Bool = false
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: item.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
                    .shadow(radius: 3)
                    .padding(.top, 4)
                
                if isHovered {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .offset(x: 4, y: -4)
                }
            }
            .frame(width: 60, height: 48)
            
            Text(item.name)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 76)
            
            Text(item.sizeString)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? Color.white.opacity(0.12) : Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(isHovered ? 0.25 : 0.08), lineWidth: 1)
                )
        )
        .onHover { isHovered = $0 }
        .onDrag {
            let provider = NSItemProvider(object: item.url as NSURL)
            provider.suggestedName = item.name
            return provider
        }
        .onTapGesture(count: 2) {
            NSWorkspace.shared.open(item.url)
        }
        .contextMenu {
            Button("Open with Default App") {
                NSWorkspace.shared.open(item.url)
            }
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            }
            Button("AirDrop...") {
                onAirDrop()
            }
            Divider()
            Button("Remove from Shelf", role: .destructive) {
                onRemove()
            }
        }
    }
}
