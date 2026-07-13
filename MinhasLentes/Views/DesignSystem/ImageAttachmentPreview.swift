import SwiftUI

/// Miniatura de uma imagem anexada (foto de receita, foto de caixa de lentes) — toque abre em
/// tamanho maior, com zoom básico (pinça + arrastar, duplo toque para alternar). Só
/// visualização, sem editor de imagem. `data == nil`/dado inválido não renderiza nada.
struct ImageAttachmentPreview: View {
    let data: Data?
    let accessibilityLabel: String
    var maxThumbnailHeight: CGFloat = 160

    @State private var showFullScreen = false

    var body: some View {
        if let data, let uiImage = UIImage(data: data) {
            Button {
                showFullScreen = true
            } label: {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: maxThumbnailHeight)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint("Abre a imagem em tamanho maior")
            .fullScreenCover(isPresented: $showFullScreen) {
                ImageAttachmentFullScreenView(uiImage: uiImage, accessibilityLabel: accessibilityLabel) {
                    showFullScreen = false
                }
            }
        }
    }
}

private struct ImageAttachmentFullScreenView: View {
    let uiImage: UIImage
    let accessibilityLabel: String
    let onClose: () -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(magnificationGesture)
                .gesture(dragGesture)
                .onTapGesture(count: 2, perform: toggleZoom)
                .accessibilityLabel(accessibilityLabel)
                .background(Color.black)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Fechar", action: onClose)
                            .tint(.white)
                    }
                }
        }
    }

    private func toggleZoom() {
        withAnimation(.spring) {
            scale = scale > 1 ? 1 : 2
            lastScale = scale
            if scale == 1 {
                offset = .zero
                lastOffset = .zero
            }
        }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = max(1, min(4, lastScale * value))
            }
            .onEnded { _ in
                lastScale = scale
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(width: lastOffset.width + value.translation.width, height: lastOffset.height + value.translation.height)
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }
}
