import SwiftUI
import SwiftData

/// Destino "Solução de limpeza" dentro da aba Cuidados: frasco atual e histórico de frascos,
/// num único lugar — editar e excluir estão sempre a um gesto de distância (deslizar a linha),
/// sem precisar navegar para outra tela. Excluir exige digitar a palavra de confirmação, por
/// ser permanente.
struct CleaningSolutionView: View {
    @Environment(\.modelContext) private var modelContext
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

    private func solutionSituationText(_ days: Int) -> String {
        if days > 0 { return "Faltam \(days) dia(s)" }
        if days == 0 { return "Validade recomendada para hoje" }
        return "Validade recomendada há \(-days) dia(s)"
    }

    var body: some View {
            List {
                Section("Frasco atual") {
                    if let activeSolution {
                        activeRow(for: activeSolution)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Excluir", role: .destructive) { solutionToDelete = activeSolution }
                                Button("Editar") { solutionToEdit = activeSolution }
                                    .tint(AppColor.primary)
                            }
                        Button {
                            showStartOrReplaceSolution = true
                        } label: {
                            Label("Abrir um novo frasco", systemImage: "flask")
                        }
                    } else {
                        Text("Nenhum frasco de solução registrado ainda.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button {
                            showStartOrReplaceSolution = true
                        } label: {
                            Label("Registrar frasco de solução", systemImage: "flask")
                        }
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

    private func activeRow(for solution: CleaningSolution) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(solution.brand) — \(solution.product)")
                .font(.subheadline.weight(.semibold))
            Text("Aberto em \(DateFormatting.short.string(from: solution.openedDate))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Descarte recomendado em \(DateFormatting.short.string(from: solution.discardDate))")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let daysUntilDiscard {
                Text(solutionSituationText(daysUntilDiscard))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(daysUntilDiscard <= 0 ? AppColor.warning : Color.secondary)
            }
            if let notes = solution.notes, !notes.isEmpty {
                Text(notes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func historyRow(for solution: CleaningSolution) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(solution.brand) — \(solution.product)")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(solution.status.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text("Aberto em \(DateFormatting.short.string(from: solution.openedDate))")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let finishedAt = solution.finishedAt {
                Text("Finalizado em \(DateFormatting.short.string(from: finishedAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let notes = solution.notes, !notes.isEmpty {
                Text(notes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        CleaningSolutionView()
    }
    .modelContainer(PreviewData.container)
}
