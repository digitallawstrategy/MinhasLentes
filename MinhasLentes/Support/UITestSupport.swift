import Foundation
import SwiftData

#if DEBUG
/// Suporte a validação visual automatizada (Codex/Xcode abrindo o app direto na Home, sem
/// interação manual) — existe inteiro só em build DEBUG, nunca compila em Release. Dois
/// argumentos de lançamento independentes, checados via `ProcessInfo.processInfo.arguments`
/// (o que `xcrun simctl launch <device> <bundle-id> --args ...` popula):
///
/// - `-UITestSkipOnboarding`: marca o onboarding como concluído, sem semear nenhum dado.
/// - `-UITestSeedPreviewData`: semeia um conjunto fixo de dados de demonstração e, por
///   coerência (dado semeado sem onboarding concluído mostraria a tela de boas-vindas por
///   cima), também marca o onboarding como concluído.
///
/// As funções aqui são puras em relação ao `ModelContext` que recebem — não sabem de onde esse
/// contexto veio (`AppContainer` decide, à parte, se é o armazenamento real ou um isolado em
/// memória) e não chamam nenhum Service/ViewModel, então nunca disparam agendamento de
/// notificação nem apresentação de Live Activity. Isso as torna testáveis diretamente com
/// `TestSupport.makeContext()`, como qualquer outro Service deste projeto.
@MainActor
enum UITestSupport {
    private static let skipOnboardingArgument = "-UITestSkipOnboarding"
    private static let seedPreviewDataArgument = "-UITestSeedPreviewData"

    /// Nome fixo do par semeado — também serve de marca de "já semeado" para `seedPreviewData`
    /// ser seguro de chamar mais de uma vez sobre o mesmo contexto.
    static let seededPairName = "Par nº 1"

    static func isSkipOnboardingRequested(arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        arguments.contains(skipOnboardingArgument)
    }

    static func isSeedPreviewDataRequested(arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        arguments.contains(seedPreviewDataArgument)
    }

    /// `true` se qualquer um dos dois argumentos estiver presente — `AppContainer` usa isto
    /// para decidir se abre o armazenamento real do App Group ou um isolado em memória; nenhum
    /// dos dois fluxos de validação visual deve chegar perto de dado real.
    static func isUITestRun(arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        isSkipOnboardingRequested(arguments: arguments) || isSeedPreviewDataRequested(arguments: arguments)
    }

    /// Marca o onboarding como concluído, sem mexer em mais nada. Idempotente por natureza: só
    /// escreve se ainda não estava marcado.
    static func applySkipOnboarding(context: ModelContext) throws {
        let settings = try AppSettingsStore.currentSettings(context: context)
        guard !settings.hasCompletedOnboarding else { return }
        settings.hasCompletedOnboarding = true
        try context.save()
    }

    /// Semeia o conjunto fixo de dados usado para validação visual da Home. Idempotente: se o
    /// par marcador (`seededPairName`, sequência 1) já existir neste contexto, não faz nada —
    /// seguro de chamar quantas vezes for preciso sobre o mesmo `ModelContext`, além de já
    /// estar protegido, na prática, por `AppContainer` sempre entregar um contexto novo e vazio
    /// para uma execução com este argumento (ver documentação lá).
    ///
    /// Dados semeados, com o "porquê" de cada valor:
    /// - 1 par "Par nº 1", `maximumUses` 60, com 2 usos já registrados (ontem e hoje) — restam
    ///   58, o número que aparece nos prints de referência da Home.
    /// - Cuidado diário de hoje já registrado.
    /// - Estojo ativo com substituição recomendada em exatamente 89 dias — `intervalDays: 89` a
    ///   partir de hoje sempre produz "em 89 dias" na tela, não importa em que dia isto rodar.
    /// - Solução de limpeza aberta hoje, para o cartão "Lembretes" ter mais de um item coerente.
    /// - Sessão "Estou usando as lentes" ativa neste par — sem isso, o botão da Home mostraria
    ///   "Estou usando as lentes" em vez de "Retirei as lentes", o estado retratado nos prints
    ///   de referência originais.
    @discardableResult
    static func seedPreviewData(context: ModelContext, referenceDate: Date = Date()) throws -> LensPair {
        let calendar = Calendar.current

        let existingDescriptor = FetchDescriptor<LensPair>(
            predicate: #Predicate { $0.name == "Par nº 1" && $0.sequenceNumber == 1 }
        )
        if let existing = try context.fetch(existingDescriptor).first {
            return existing
        }

        let settings = try AppSettingsStore.currentSettings(context: context)
        settings.hasCompletedOnboarding = true

        let pairStartDate = calendar.date(byAdding: .day, value: -2, to: referenceDate) ?? referenceDate
        let yesterday = calendar.date(byAdding: .day, value: -1, to: referenceDate) ?? referenceDate

        let pair = LensPair(
            name: seededPairName,
            sequenceNumber: 1,
            startDate: pairStartDate,
            maximumUses: 60,
            trackingMode: .pair,
            side: .both
        )
        context.insert(pair)
        context.insert(LensUsage(date: yesterday, side: .both, lensPair: pair))
        context.insert(LensUsage(date: referenceDate, side: .both, lensPair: pair))

        context.insert(RoutineCareLog(date: referenceDate))
        context.insert(LensCase(startDate: referenceDate, intervalDays: 89))
        context.insert(CleaningSolution(
            brand: "Marca de exemplo",
            product: "Solução multiuso",
            openedDate: referenceDate,
            postOpeningShelfLifeDays: 90
        ))
        context.insert(WearSession(startedAt: referenceDate, lensPair: pair))

        try context.save()
        return pair
    }
}
#endif
