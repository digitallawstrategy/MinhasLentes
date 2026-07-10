import SwiftUI
import SwiftData

/// Fluxo exibido na primeira abertura, quando ainda não existe nenhum par ativo.
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allSettings: [AppSettings]

    @State private var viewModel = OnboardingViewModel()
    @State private var showNotificationExplanation = false
    @State private var settingsLoadError: IdentifiableError?

    private var settings: AppSettings? {
        allSettings.first
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Novo par de lentes") {
                    DatePicker("Data de início", selection: $viewModel.startDate, displayedComponents: .date)
                    Stepper("Limite de usos: \(viewModel.maximumUses)", value: $viewModel.maximumUses, in: 1...500)
                    Picker("Modo de controle", selection: $viewModel.trackingMode) {
                        ForEach(TrackingMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                }

                Section("Estojo") {
                    DatePicker("Última limpeza registrada", selection: $viewModel.lastCleaningDate, displayedComponents: .date)
                }

                Section("Notificações") {
                    Toggle("Ativar lembretes de limpeza", isOn: $viewModel.wantsNotifications)
                }
            }
            .navigationTitle("Bem-vindo")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await start() }
                    } label: {
                        if viewModel.isCompleting {
                            ProgressView()
                        } else {
                            Text("Começar")
                        }
                    }
                    .disabled(viewModel.isCompleting || settings == nil)
                }
            }
            .task {
                do {
                    _ = try AppSettingsStore.currentSettings(context: modelContext)
                } catch {
                    settingsLoadError = IdentifiableError(error)
                }
            }
            .fullScreenCover(isPresented: $showNotificationExplanation) {
                NotificationPermissionView(
                    onContinue: {
                        Task {
                            if let settings {
                                await viewModel.requestNotificationsAndSchedule(settings: settings)
                            }
                            showNotificationExplanation = false
                        }
                    },
                    onSkip: {
                        showNotificationExplanation = false
                    }
                )
            }
            .alert(
                "Não foi possível preparar o armazenamento",
                isPresented: Binding(
                    get: { settingsLoadError != nil },
                    set: { if !$0 { settingsLoadError = nil } }
                ),
                presenting: settingsLoadError
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { error in
                Text(error.message)
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

    private func start() async {
        guard let settings else { return }
        let success = await viewModel.createInitialData(settings: settings, context: modelContext)
        if success, viewModel.wantsNotifications {
            showNotificationExplanation = true
        }
    }
}

#Preview {
    OnboardingView()
        .modelContainer(for: [LensPair.self, LensUsage.self, CaseCleaning.self, AppSettings.self, HistoryEvent.self], inMemory: true)
}
