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

    private var settings: AppSettings {
        allSettings.first ?? AppSettings()
    }

    private var lastCleaning: CaseCleaning? { cleanings.first }

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
                            if let advanceReminderDate {
                                StatRow(label: "Aviso antecipado", value: DateFormatting.short.string(from: advanceReminderDate))
                            }
                            if let nextCleaningDate {
                                StatRow(label: "Prazo da limpeza", value: DateFormatting.short.string(from: nextCleaningDate))
                            }
                            StatRow(label: "Intervalo configurado", value: "\(settings.cleaningIntervalDays) dias")
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
    }
}

#Preview {
    CaseView()
        .modelContainer(PreviewData.container)
}
