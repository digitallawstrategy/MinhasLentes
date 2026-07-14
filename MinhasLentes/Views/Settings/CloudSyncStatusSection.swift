import SwiftUI
import CloudKit
import CoreData

/// Observa o estado de sincronização do store com CloudKit — o SwiftData não expõe isso
/// diretamente no `ModelContainer`, mas o mirroring por baixo dos panos é feito por um
/// `NSPersistentCloudKitContainer`, que posta `eventChangedNotification` via `NotificationCenter`
/// independente de referência direta ao container (mesmo mecanismo que o Core Data usa há anos).
@MainActor
@Observable
final class CloudSyncStatusMonitor {
    enum State: Equatable {
        /// Ainda no store legado — `CloudSyncMigrationService`/`AppContainer` ainda não migraram
        /// (sem conta iCloud disponível na primeira execução, ou a migração ainda não rodou).
        case local
        case unavailable
        case syncing
        case active(lastSyncDate: Date?)
    }

    private(set) var state: State = .local
    private var eventObserver: NSObjectProtocol?
    private var accountObserver: NSObjectProtocol?

    func start() {
        guard AppGroup.isCloudMigrationComplete else {
            state = .local
            return
        }
        state = .syncing
        Task { await refreshAccountStatus() }

        eventObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main
        ) { [weak self] notification in
            // Extrai só os valores primitivos (Sendable) antes de cruzar pro MainActor —
            // `Notification`/`NSPersistentCloudKitContainer.Event` não são Sendable, então não
            // podem atravessar a fronteira de concorrência direto no `Task`.
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else { return }
            let endDate = event.endDate
            let succeeded = event.succeeded
            Task { @MainActor in self?.handleEvent(endDate: endDate, succeeded: succeeded) }
        }
        accountObserver = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { await self?.refreshAccountStatus() }
        }
    }

    func stop() {
        if let eventObserver { NotificationCenter.default.removeObserver(eventObserver) }
        if let accountObserver { NotificationCenter.default.removeObserver(accountObserver) }
        eventObserver = nil
        accountObserver = nil
    }

    private func refreshAccountStatus() async {
        guard AppGroup.isCloudMigrationComplete else {
            state = .local
            return
        }
        let status = try? await CKContainer.default().accountStatus()
        guard status == .available else {
            state = .unavailable
            return
        }
        if case .unavailable = state {
            state = .syncing
        }
    }

    private func handleEvent(endDate: Date?, succeeded: Bool) {
        guard AppGroup.isCloudMigrationComplete else { return }
        if endDate == nil {
            state = .syncing
        } else if succeeded {
            state = .active(lastSyncDate: endDate)
        } else {
            state = .unavailable
        }
    }
}

/// Seção discreta, só leitura — sem nenhum botão de ação. Ativo/Sincronizando/Indisponível/Local,
/// e a data da última sincronização bem-sucedida quando houver.
struct CloudSyncStatusSection: View {
    @State private var monitor = CloudSyncStatusMonitor()

    var body: some View {
        Section {
            LabeledContent("Status") {
                Text(statusText)
                    .foregroundStyle(statusTone)
            }
            if case .active(let lastSyncDate) = monitor.state, let lastSyncDate {
                LabeledContent("Última sincronização", value: DateFormatting.shortWithTime.string(from: lastSyncDate))
            }
        } header: {
            Text("iCloud Sync")
        } footer: {
            Text(footerText)
        }
        .task { monitor.start() }
        .onDisappear { monitor.stop() }
    }

    private var statusText: String {
        switch monitor.state {
        case .local: return "Local"
        case .unavailable: return "Indisponível"
        case .syncing: return "Sincronizando…"
        case .active: return "Ativo"
        }
    }

    private var statusTone: Color {
        switch monitor.state {
        case .local: return .secondary
        case .unavailable: return AppColor.warning
        case .syncing: return .secondary
        case .active: return AppColor.success
        }
    }

    private var footerText: String {
        switch monitor.state {
        case .local:
            return "Seus dados estão só neste aparelho por enquanto. Assim que houver conta iCloud disponível, a sincronização começa automaticamente, sem apagar nada."
        case .unavailable:
            return "Verifique se você está conectado à sua conta iCloud em Ajustes. Seus dados continuam salvos normalmente neste aparelho enquanto isso."
        case .syncing:
            return "Sincronizando os dados com o iCloud."
        case .active:
            return "Seus dados estão sincronizados com o iCloud e disponíveis nos seus outros aparelhos."
        }
    }
}

#Preview {
    Form {
        CloudSyncStatusSection()
    }
}
