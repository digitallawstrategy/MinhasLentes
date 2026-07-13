import SwiftUI
import SwiftData

/// Destino "Solução de limpeza" dentro da aba Cuidados: frasco atual e histórico de frascos,
/// num único lugar — editar e excluir estão sempre a um gesto de distância (deslizar a linha),
/// sem precisar navegar para outra tela. Excluir exige digitar a palavra de confirmação, por
/// ser permanente.
struct CleaningSolutionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \CleaningSolution.openedDate, order: .reverse) private var solutions: [CleaningSolution]
    @Query private var allSettings: [AppSettings]

    @State private var viewModel = CleaningSolutionViewModel()
    @State private var showStartOrReplaceSolution = false
    @State private var solutionToEdit: CleaningSolution?
    @State private var solutionToDelete: CleaningSolution?

    private var settings: AppSettings {
        allSettings.first ?? AppSettings()
    }

    private var activeSolution: CleaningSolution? { solutions.first { $0.status == .active } }
    private var pastSolutions: [CleaningSolution] { solutions.filter { $0.status != .active } }

    private var daysUntilDiscard: Int? {
        guard let activeSolution else { return nil }
        return LensStatisticsService.daysUntil(activeSolution.discardDate)
    }

    private var discardTone: AppStatusTone {
        guard let daysUntilDiscard else { return .informative }
        if daysUntilDiscard <= 0 { return .critical }
        if daysUntilDiscard <= settings.advanceReminderDays { return .warning }
        return .success
    }

    private var discardStatusText: String {
        guard let daysUntilDiscard else { return "Sem validade calculada" }
        if daysUntilDiscard > 0 { return "\(Pluralization.word(daysUntilDiscard, "Falta", "Faltam")) \(Pluralization.count(daysUntilDiscard, "dia", "dias"))" }
        if daysUntilDiscard == 0 { return "Descarte recomendado hoje" }
        return "Descarte recomendado há \(Pluralization.count(-daysUntilDiscard, "dia", "dias"))"
    }

    var body: some View {
            List {
                Section("Frasco atual") {
                    if let activeSolution {
                        activeSolutionCard(for: activeSolution)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Excluir", role: .destructive) { solutionToDelete = activeSolution }
                                Button("Editar") { solutionToEdit = activeSolution }
                                    .tint(AppColor.primary)
                            }
                    } else {
                        Text("Nenhum frasco de solução registrado ainda.")
                            .font(AppTypography.subheadline)
                            .foregroundStyle(.secondary)
                        PrimaryActionButton(title: "Registrar frasco de solução", systemImage: "flask") {
                            showStartOrReplaceSolution = true
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .padding(.vertical, AppSpacing.xxs)
                    }
                }

                if !pastSolutions.isEmpty {
                    Section("Histórico") {
                        ForEach(pastSolutions) { solution in
                            historyRow(for: solution)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button("Excluir", role: .destructive) { solutionToDelete = solution }
                                    Button("Editar") { solutionToEdit = solution }
                                        .tint(AppColor.primary)
                                }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .tabBarScrollInset()
            .background(AmbientBackground())
            .navigationTitle("Solução")
            .sheet(isPresented: $showStartOrReplaceSolution) {
                StartOrReplaceSolutionSheet(isReplacing: activeSolution != nil) { brand, product, lot, purchaseDate, openedDate, printedExpiryDate, shelfLifeDays, initialVolume, notes in
                    Task {
                        await viewModel.startOrReplaceSolution(
                            brand: brand, product: product, lot: lot, purchaseDate: purchaseDate, openedDate: openedDate,
                            printedExpiryDate: printedExpiryDate, postOpeningShelfLifeDays: shelfLifeDays,
                            initialVolumeML: initialVolume, notes: notes, settings: settings, context: modelContext
                        )
                    }
                }
            }
            .sheet(item: $solutionToEdit) { solution in
                EditCleaningSolutionSheet(solution: solution) { brand, product, lot, purchaseDate, openedDate, printedExpiryDate, shelfLifeDays, initialVolume, remainingVolume, notes in
                    Task {
                        await viewModel.editSolution(
                            solution, brand: brand, product: product, lot: lot, purchaseDate: purchaseDate, openedDate: openedDate,
                            printedExpiryDate: printedExpiryDate, postOpeningShelfLifeDays: shelfLifeDays,
                            initialVolumeML: initialVolume, remainingVolumeML: remainingVolume, notes: notes,
                            settings: settings, context: modelContext
                        )
                    }
                }
            }
            .sheet(item: $solutionToDelete) { solution in
                ConfirmDeleteByTypingSheet(
                    title: "Excluir frasco",
                    message: "Isso exclui permanentemente o registro do frasco de \(solution.brand) \(solution.product), aberto em \(DateFormatting.short.string(from: solution.openedDate)). Se for o frasco ativo, os avisos de validade são cancelados até que um novo frasco seja aberto."
                ) {
                    Task { await viewModel.deleteSolution(solution, context: modelContext) }
                }
            }
            .alert(
                "Não foi possível concluir a ação",
                isPresented: Binding(
                    get: { viewModel.presentedError != nil },
                    set: { if !$0 { viewModel.presentedError = nil } }
                ),
                presenting: viewModel.presentedError
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { error in
                Text(error.message)
            }
    }

    /// Cartão-passe, no espírito de um passe de Wallet: identificação, aberto em, descarte
    /// recomendado, dias restantes e a ação principal do frasco — tudo no mesmo lugar, sem
    /// precisar ler três linhas soltas para entender a situação.
    private func activeSolutionCard(for solution: CleaningSolution) -> some View {
        AppCard(variant: .featured) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    solutionTitleBlock(for: solution)
                    // Mesmo sozinho na própria linha, sem nenhum vizinho disputando espaço, o
                    // selo truncava ("Faltam 90...") em accessibility-XXXL — o texto simplesmente
                    // não cabe numa linha só nesse tamanho de fonte, nem com a tela inteira à
                    // disposição. `lineLimit: nil` deixa a pílula crescer em altura (2 linhas) em
                    // vez de truncar ou (com `.fixedSize()`, tentado antes) ficar maior que a
                    // tela e cortar visualmente.
                    StatusBadge(text: discardStatusText, tone: discardTone, systemImage: "flask.fill", lineLimit: nil)
                }
            } else {
                HStack(alignment: .top) {
                    solutionTitleBlock(for: solution)
                    Spacer(minLength: AppSpacing.xs)
                    StatusBadge(text: discardStatusText, tone: discardTone, systemImage: "flask.fill")
                }
            }
            Text("Descarte recomendado em \(DateFormatting.short.string(from: solution.discardDate))")
                .font(AppTypography.footnote)
                .foregroundStyle(.secondary)
            if let notes = solution.notes, !notes.isEmpty {
                Text(notes)
                    .font(AppTypography.footnote)
                    .foregroundStyle(.secondary)
            }
            PrimaryActionButton(title: "Abrir novo frasco", systemImage: "flask", action: { showStartOrReplaceSolution = true })
                .padding(.top, AppSpacing.xxs)
        }
        .padding(.vertical, AppSpacing.xxs)
    }

    private func solutionTitleBlock(for solution: CleaningSolution) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(solution.brand) — \(solution.product)")
                .font(AppTypography.headline)
            Text("Aberto em \(DateFormatting.short.string(from: solution.openedDate))")
                .font(AppTypography.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func historyRow(for solution: CleaningSolution) -> some View {
        AppListRow(
            systemImage: "flask",
            tone: .neutral,
            title: "\(solution.brand) — \(solution.product)",
            subtitle: solution.finishedAt.map { "Aberto em \(DateFormatting.short.string(from: solution.openedDate)) · Finalizado em \(DateFormatting.short.string(from: $0))" }
                ?? "Aberto em \(DateFormatting.short.string(from: solution.openedDate))",
            trailingText: solution.status.displayName
        )
    }
}

#Preview {
    NavigationStack {
        CleaningSolutionView()
    }
    .modelContainer(PreviewData.container)
}
