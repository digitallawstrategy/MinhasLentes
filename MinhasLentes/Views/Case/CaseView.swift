import SwiftUI
import SwiftData

/// Aba Estojo: última limpeza, próximos avisos e histórico de limpezas.
struct CaseView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CaseCleaning.cleaningDate, order: .reverse) private var cleanings: [CaseCleaning]
    @Query private var allSettings: [AppSettings]

    @State private var viewModel = CaseViewModel()
    @State private var showRegisterOtherDate = false
    @State private var customDate = Date()
    @State private var customNotes = ""
    @State private var cleaningToDelete: CaseCleaning?
    @State private var cleaningToEdit: CaseCleaning?

    private var settings: AppSettings {
        allSettings.first ?? AppSettings()
    }

    private var lastCleaning: CaseCleaning? { cleanings.first }

    private var daysSinceLastCleaning: Int? {
        guard let lastCleaning else { return nil }
        return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: lastCleaning.cleaningDate), to: Calendar.current.startOfDay(for: Date())).day
    }

    private var daysUntilNextCleaning: Int? {
        guard let nextCleaningDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: nextCleaningDate)).day
    }

    private var countdownFraction: Double {
        guard let daysUntilNextCleaning, settings.cleaningIntervalDays > 0 else { return 0 }
        return min(max(Double(daysUntilNextCleaning) / Double(settings.cleaningIntervalDays), 0), 1)
    }

    private var countdownTint: Color {
        guard let daysUntilNextCleaning else { return .accentColor }
        if daysUntilNextCleaning <= 0 { return .red }
        if daysUntilNextCleaning <= settings.advanceReminderDays { return .orange }
        return .green
    }

    private var nextCleaningDate: Date? {
        guard let lastCleaning else { return nil }
        return LensStatisticsService.nextCleaningDate(
            lastCleaningDate: lastCleaning.cleaningDate,
            intervalDays: settings.cleaningIntervalDays
        )
    }

    private var advanceReminderDate: Date? {
        guard let lastCleaning else { return nil }
        return LensStatisticsService.advanceReminderDate(
            lastCleaningDate: lastCleaning.cleaningDate,
            intervalDays: settings.cleaningIntervalDays,
            advanceDays: settings.advanceReminderDays
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SectionCard(title: "Estojo") {
                        VStack(spacing: 6) {
                            if let lastCleaning {
                                StatRow(label: "Última limpeza", value: DateFormatting.short.string(from: lastCleaning.cleaningDate))
                            } else {
                                StatRow(label: "Última limpeza", value: "Nenhuma registrada")
                            }
                            if let daysSinceLastCleaning {
                                StatRow(label: "Dias desde a limpeza", value: "\(daysSinceLastCleaning) dia(s)")
                            }
                            if let advanceReminderDate {
                                StatRow(label: "Aviso antecipado", value: DateFormatting.short.string(from: advanceReminderDate))
                            }
                            if let nextCleaningDate {
                                StatRow(label: "Prazo da limpeza", value: DateFormatting.short.string(from: nextCleaningDate))
                            }
                            StatRow(label: "Intervalo configurado", value: "\(settings.cleaningIntervalDays) dias")
                        }

                        if let daysUntilNextCleaning {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(daysUntilNextCleaning <= 0 ? "Limpeza atrasada" : "Faltam \(daysUntilNextCleaning) dia(s) para a próxima limpeza")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(countdownTint)
                                ProgressBarView(fraction: countdownFraction, tint: countdownTint)
                                    .animation(.easeInOut(duration: 0.6), value: countdownFraction)
                            }
                            .padding(.top, 4)
                        }

                        VStack(spacing: 10) {
                            Button {
                                Task { await viewModel.registerCleaningToday(settings: settings, context: modelContext) }
                            } label: {
                                Label("Limpei o estojo hoje", systemImage: "sparkles")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)

                            Button("Registrar em outra data") {
                                customDate = Date()
                                customNotes = ""
                                showRegisterOtherDate = true
                            }
                            .font(.subheadline)
                        }
                        .padding(.top, 4)
                    }

                    SectionCard(title: "Histórico de limpezas") {
                        if cleanings.isEmpty {
                            Text("Nenhuma limpeza registrada ainda.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(cleanings) { cleaning in
                                    HStack(alignment: .top) {
                                        Image(systemName: "sparkles")
                                            .foregroundStyle(Color.accentColor)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(DateFormatting.shortWithTime.string(from: cleaning.cleaningDate))
                                                .font(.subheadline.weight(.medium))
                                            if let notes = cleaning.notes, !notes.isEmpty {
                                                Text(notes)
                                                    .font(.footnote)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Button {
                                            cleaningToEdit = cleaning
                                        } label: {
                                            Image(systemName: "pencil")
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Editar limpeza de \(DateFormatting.shortWithTime.string(from: cleaning.cleaningDate))")

                                        Button(role: .destructive) {
                                            cleaningToDelete = cleaning
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Excluir limpeza de \(DateFormatting.shortWithTime.string(from: cleaning.cleaningDate))")
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .navigationTitle("Estojo")
            .sheet(isPresented: $showRegisterOtherDate) {
                NavigationStack {
                    Form {
                        DatePicker("Data da limpeza", selection: $customDate, displayedComponents: [.date, .hourAndMinute])
                        TextField("Observação (opcional)", text: $customNotes, axis: .vertical)
                            .lineLimit(2...4)
                    }
                    .navigationTitle("Registrar limpeza")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancelar") { showRegisterOtherDate = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Salvar") {
                                Task {
                                    await viewModel.registerCleaning(
                                        date: customDate,
                                        notes: customNotes.isEmpty ? nil : customNotes,
                                        settings: settings,
                                        context: modelContext
                                    )
                                    showRegisterOtherDate = false
                                }
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .sheet(item: $cleaningToEdit) { cleaning in
                EditCleaningSheet(cleaning: cleaning) { date, notes in
                    Task { await viewModel.editCleaning(cleaning, newDate: date, newNotes: notes, settings: settings, context: modelContext) }
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
            .alert(
                "Excluir limpeza?",
                isPresented: Binding(
                    get: { cleaningToDelete != nil },
                    set: { if !$0 { cleaningToDelete = nil } }
                )
            ) {
                Button("Cancelar", role: .cancel) { cleaningToDelete = nil }
                Button("Excluir", role: .destructive) {
                    if let cleaning = cleaningToDelete {
                        Task { await viewModel.deleteCleaning(cleaning, settings: settings, context: modelContext) }
                    }
                    cleaningToDelete = nil
                }
            } message: {
                Text("Os avisos de limpeza serão recalculados a partir do registro anterior, se houver.")
            }
        }
    }
}

#Preview {
    CaseView()
        .modelContainer(PreviewData.container)
}
