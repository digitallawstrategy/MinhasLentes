import AppIntents

/// Frases nativas da Siri para os dois comandos de voz — em português e inglês. Toda frase
/// registrada aqui PRECISA incluir `\(.applicationName)` (exigência do framework para App
/// Shortcuts); é por isso que "Siri, estou de lentes" sozinho (sem o nome do app) não funciona
/// direto por voz em todo idioma/configuração — para essa frase exata, o usuário cria um Atalho
/// pessoal na Central de Atalhos apontando para `StartWearingLensesIntent`, contornando a
/// exigência do nome do app nas frases nativas.
struct LensShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartWearingLensesIntent(),
            phrases: [
                "Estou de lentes no \(.applicationName)",
                "Comecei a usar lentes no \(.applicationName)",
                "Estou usando lentes no \(.applicationName)",
                "I'm wearing lenses in \(.applicationName)",
                "I'm wearing my contacts in \(.applicationName)",
                "I started wearing my lenses in \(.applicationName)",
            ],
            shortTitle: "Estou de lentes",
            systemImageName: "eye.circle.fill"
        )
        AppShortcut(
            intent: EndWearingLensesIntent(),
            phrases: [
                "Tirei as lentes no \(.applicationName)",
                "I took my lenses off in \(.applicationName)",
            ],
            shortTitle: "Tirei as lentes",
            systemImageName: "checkmark.circle.fill"
        )
    }
}
