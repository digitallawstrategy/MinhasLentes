import SwiftUI

/// Tela explicativa exibida antes de solicitar a autorização de notificações do iOS.
struct NotificationPermissionView: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bell.badge")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text("Lembretes de limpeza")
                    .font(.title2.weight(.semibold))
                Text("As notificações são utilizadas para lembrar a limpeza periódica do estojo das lentes.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
            }

            Spacer()

            VStack(spacing: 12) {
                Button(action: onContinue) {
                    Text("Permitir notificações")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Agora não", action: onSkip)
                    .font(.subheadline)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}

#Preview {
    NotificationPermissionView(onContinue: {}, onSkip: {})
}
