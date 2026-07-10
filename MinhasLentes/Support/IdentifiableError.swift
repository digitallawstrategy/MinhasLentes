import Foundation

/// Envelope simples para apresentar qualquer `Error` através de `.alert(item:)` do SwiftUI,
/// que exige um valor `Identifiable`. Usado por todas as ViewModels para expor falhas de
/// operações críticas (salvar, excluir, encerrar, agendar notificação, exportar, importar,
/// apagar dados) de forma compreensível ao usuário — nunca silenciosamente.
struct IdentifiableError: Identifiable {
    let id = UUID()
    let message: String

    init(_ error: Error) {
        self.message = error.localizedDescription
    }

    init(message: String) {
        self.message = message
    }
}
