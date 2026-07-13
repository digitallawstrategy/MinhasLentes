import SwiftUI
import SwiftData

/// Aba Início: o hub de ações do dia — registrar o uso de hoje, alternar a sessão "estou
/// usando as lentes", registrar o cuidado diário do estojo e, quando pertinente, a limpeza
/// periódica. Edição, encerramento e detalhe administrativo ficam em Lentes/Cuidados; tocar
/// num par aqui leva direto ao diário dele lá. Prioridade visual, nesta ordem: situação das
/// lentes em uso, ação principal do momento, sessão ativa, cuidados de hoje, lembretes.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \LensPair.sequenceNumber) private var allPairs: [LensPair]
    @Query private var allSettings: [AppSettings]
    @Query(sort: \CaseCleaning.cleaningDate, order: .reverse) private var cleanings: [CaseCleaning]
    @Query(sort: \LensCase.startDate, order: .reverse) private var cases: [LensCase]
    @Query(sort: \CleaningSolution.openedDate, order: .reverse) private var solutions: [CleaningSolution]
    @Query(sort: \EyeAppointment.date) private var appointments: [EyeAppointment]
    @Query(sort: \RoutineCareLog.date, order: .reverse) private var routineCareLogs: [RoutineCareLog]
    @Query(sort: \LensInventoryItem.createdAt, order: .reverse) private var inventoryItems: [LensInventoryItem]

    @State private var caseViewModel = CaseCleaningViewModel()
    @State private var pairsViewModel = LensPairsViewModel()
    @State private var routineCareViewModel = RoutineCareViewModel()
    @State private var router = AppRouter.shared
    @State private var showRoutineCarePrompt = false
    @State private var pendingSessionStartPair: LensPair?
    @State private var showRegisterRoutineCareDetails = false
    @State private var routineDate = Date()
    @State private var routineDiscardedSolution = true
    @State private var routineCleanedCase = true
    @State private var routineAirDried = true
    @State private var routineNotes = ""

    private var settings: AppSettings {
        allSettings.first ?? AppSettings()
    }

    private var inUsePairs: [LensPair] {
        allPairs.filter { $0.status == .inUse && $0.deletedAt == nil }
    }

    private var reservePairs: [LensPair] {
        allPairs.filter { $0.status == .reserve && $0.deletedAt == nil }
    }

    private var lastCleaning: CaseCleaning? { cleanings.first }
    private var lastRoutineCare: RoutineCareLog? { routineCareLogs.first }
    private var activeCase: LensCase? { cases.first { $0.status == .active } }
    private var activeSolution: CleaningSolution? { solutions.first { $0.status == .active } }
    private var nextAppointment: EyeAppointment? {
        appointments.first { $0.status == .scheduled && $0.date >= Date() }
    }

    private var availableInventoryItems: [LensInventoryItem] {
        inventoryItems.filter { $0.status == .available && $0.remainingQuantity > 0 }
    }

    private var expiringInventoryItems: [LensInventoryItem] {
        LensInventoryStatisticsService.itemsNearExpiry(items: availableInventoryItems, withinDays: 30)
    }

    /// Verifica todos os registros do dia, não só o primeiro da lista — um registro futuro
    /// (relógio errado, engano de data em "Registrar em outro dia") ordenaria antes do de hoje e
    /// faria o app deixar de perceber um cuidado diário já feito hoje.
    private var hasRoutineCareToday: Bool {
        routineCareLogs.contains { Calendar.current.isDate($0.date, inSameDayAs: Date()) }
    }

    /// Mesma janela usada por `TodayCareCardView` para decidir se a limpeza periódica precisa
    /// de destaque — replicada aqui só para a checagem de "tudo em dia", sem acoplar as Views.
    private var isCleaningDue: Bool {
        guard let lastCleaning else { return true }
        let nextDate = LensStatisticsService.nextCleaningDate(lastCleaningDate: lastCleaning.cleaningDate, intervalDays: settings.cleaningIntervalDays)
        return LensStatisticsService.daysUntil(nextDate) <= settings.advanceReminderDays
    }

    /// Nada pendente para hoje: sem uso a registrar, cuidado diário feito, limpeza periódica
    /// fora da janela de aviso e sem lembretes — mostra uma mensagem discreta no lugar do
    /// cartão de lembretes, em vez de somar mais um cartão à tela.
    private var isEverythingSettled: Bool {
        pairsNeedingUsageToday.isEmpty && hasRoutineCareToday && !isCleaningDue && reminderItems.isEmpty
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 0..<12: return "Bom dia"
        case 12..<18: return "Boa tarde"
        default: return "Boa noite"
        }
    }

    /// Fixa e não some quando "tudo em dia" — essa confirmação já tem seu próprio lugar
    /// discreto (`everythingSettledRow`); duplicá-la aqui só repetiria a mesma frase duas vezes
    /// na mesma tela.
    private let greetingSubtitle = "Vamos cuidar bem das suas lentes hoje."

    var body: some View {
        NavigationStack {
            withDialogsAndSheet(withErrorAlerts(mainContent))
        }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: AppSpacing.md) {
                HomeHeaderView(greeting: greeting, subtitle: greetingSubtitle) {
                    router.selectedTab = .settings
                }

                if inUsePairs.isEmpty && reservePairs.isEmpty {
                    EmptyStateView(
                        title: "Nenhum par cadastrado",
                        systemImage: "eyeglasses",
                        description: "Vá para a aba Lentes para iniciar seu primeiro par.",
                        actionTitle: "Ir para Lentes",
                        actionSystemImage: "arrow.right.circle.fill"
                    ) {
                        router.selectedTab = .lentes
                    }
                } else {
                    summaryContent
                }

                if isEverythingSettled {
                    everythingSettledRow
                } else if !reminderItems.isEmpty {
                    remindersCard
                }

                TodayCareCardView(
                    lastRoutineCare: lastRoutineCare,
                    hasRoutineCareToday: hasRoutineCareToday,
                    lastCleaning: lastCleaning,
                    settings: settings,
                    onRegisterRoutineCareToday: {
                        routineCareViewModel.registerRoutineCareToday(context: modelContext)
                    },
                    onRegisterRoutineCareForOtherDay: {
                        routineDate = Date()
                        routineDiscardedSolution = true
                        routineCleanedCase = true
                        routineAirDried = true
                        routineNotes = ""
                        showRegisterRoutineCareDetails = true
                    },
                    onRegisterCleaningToday: {
                        Task { await caseViewModel.registerCleaningToday(settings: settings, context: modelContext) }
                    }
                )
            }
            .padding(.horizontal)
            .padding(.top, AppSpacing.xs)
            .padding(.bottom, AppSpacing.sm)
        }
        .tabBarScrollInset()
        .background(AmbientBackground())
        .navigationTitle("Início")
        .toolbar(.hidden, for: .navigationBar)
        .task {
            pairsViewModel.refreshWearingSessionState(context: modelContext)
            await endPendingWearingSessionIfNeeded()
        }
        .onChange(of: router.pendingEndWearingSession) { _, _ in
            Task { await endPendingWearingSessionIfNeeded() }
        }
        .overlay(alignment: .bottom) {
            if caseViewModel.showUndoToast, let message = caseViewModel.toastMessage {
                ConfirmationToast(message: message, actionTitle: "Desfazer") {
                    Task { await caseViewModel.undoLastRegisteredCleaning(settings: settings, context: modelContext) }
                }
                .padding(.bottom, AppSpacing.xs)
                .transition(toastTransition)
            } else if pairsViewModel.showUndoToast, let message = pairsViewModel.toastMessage {
                ConfirmationToast(message: message, actionTitle: "Desfazer") {
                    pairsViewModel.undoLastRegisteredUsage(context: modelContext)
                }
                .padding(.bottom, AppSpacing.xs)
                .transition(toastTransition)
            } else if routineCareViewModel.showUndoToast, let message = routineCareViewModel.toastMessage {
                ConfirmationToast(message: message, actionTitle: "Desfazer") {
                    routineCareViewModel.undoLastRegisteredRoutineCare(context: modelContext)
                }
                .padding(.bottom, AppSpacing.xs)
                .transition(toastTransition)
            }
        }
        .animation(reduceMotion ? nil : AppAnimation.standard, value: caseViewModel.showUndoToast)
        .animation(reduceMotion ? nil : AppAnimation.standard, value: pairsViewModel.showUndoToast)
        .animation(reduceMotion ? nil : AppAnimation.standard, value: routineCareViewModel.showUndoToast)
    }

    /// Sem Reduce Motion: desliza e some. Com Reduce Motion: só aparece/desaparece — a
    /// movimentação é exatamente o que essa preferência de acessibilidade pede para evitar.
    private var toastTransition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity)
    }

    @ViewBuilder
    private func withErrorAlerts(_ content: some View) -> some View {
        content
            .alert(
                "Não foi possível concluir a ação",
                isPresented: Binding(
                    get: { caseViewModel.presentedError != nil },
                    set: { if !$0 { caseViewModel.presentedError = nil } }
                ),
                presenting: caseViewModel.presentedError
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { error in
                Text(error.message)
            }
            .alert(
                "Não foi possível concluir a ação",
                isPresented: Binding(
                    get: { pairsViewModel.presentedError != nil },
                    set: { if !$0 { pairsViewModel.presentedError = nil } }
                ),
                presenting: pairsViewModel.presentedError
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { error in
                Text(error.message)
            }
            .alert(
                "Não foi possível concluir a ação",
                isPresented: Binding(
                    get: { routineCareViewModel.presentedError != nil },
                    set: { if !$0 { routineCareViewModel.presentedError = nil } }
                ),
                presenting: routineCareViewModel.presentedError
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { error in
                Text(error.message)
            }
    }

    @ViewBuilder
    private func withDialogsAndSheet(_ content: some View) -> some View {
        content
            .alert("Limite atingido", isPresented: $pairsViewModel.showLimitReachedAlert) {
                Button("Entendi", role: .cancel) {}
            } message: {
                Text("O limite de utilizações de um dos pares foi atingido. Nada foi registrado — substitua as lentes antes de tentar de novo.")
            }
            .confirmationDialog(
                "Já existe uma utilização registrada nesta data em pelo menos um par. Registrar mesmo assim, em todos os pares deste lote?",
                isPresented: $pairsViewModel.showDuplicateConfirmation,
                titleVisibility: .visible
            ) {
                Button("Registrar mesmo assim") {
                    pairsViewModel.confirmDuplicateRegistration(settings: settings, context: modelContext)
                }
                Button("Cancelar", role: .cancel) {
                    pairsViewModel.cancelDuplicateRegistration()
                }
            }
            .confirmationDialog(
                "Registrar cuidado diário do estojo?",
                isPresented: $showRoutineCarePrompt,
                titleVisibility: .visible
            ) {
                Button("Registrar") {
                    routineCareViewModel.registerRoutineCareToday(context: modelContext)
                }
                Button("Depois", role: .cancel) {}
            }
            .confirmationDialog(
                "Registrar também a utilização de hoje?",
                isPresented: sessionStartPromptBinding,
                titleVisibility: .visible
            ) {
                Button("Registrar e iniciar sessão") {
                    if let pair = pendingSessionStartPair {
                        pairsViewModel.registerUsageToday(for: pair, side: pair.side, settings: settings, context: modelContext)
                        pairsViewModel.toggleWearingSession(for: pair, settings: settings, context: modelContext)
                    }
                    pendingSessionStartPair = nil
                }
                Button("Apenas iniciar sessão") {
                    if let pair = pendingSessionStartPair {
                        pairsViewModel.toggleWearingSession(for: pair, settings: settings, context: modelContext)
                    }
                    pendingSessionStartPair = nil
                }
                Button("Cancelar", role: .cancel) {
                    pendingSessionStartPair = nil
                }
            }
            .confirmationDialog(
                "Já existe um cuidado diário registrado nesta data. Registrar mesmo assim?",
                isPresented: $routineCareViewModel.showDuplicateConfirmation,
                titleVisibility: .visible
            ) {
                Button("Registrar mesmo assim") {
                    routineCareViewModel.confirmDuplicateRegistration(context: modelContext)
                }
                Button("Cancelar", role: .cancel) {
                    routineCareViewModel.cancelDuplicateRegistration()
                }
            }
            .sheet(isPresented: $showRegisterRoutineCareDetails) {
                NavigationStack {
                    Form {
                        DatePicker("Data", selection: $routineDate, displayedComponents: [.date, .hourAndMinute])
                        Toggle("Descartei a solução usada", isOn: $routineDiscardedSolution)
                        Toggle("Limpei o estojo", isOn: $routineCleanedCase)
                        Toggle("Deixei secar ao ar livre", isOn: $routineAirDried)
                        TextField("Observação (opcional)", text: $routineNotes, axis: .vertical)
                            .lineLimit(2...4)
                    }
                    .navigationTitle("Cuidado diário")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancelar") { showRegisterRoutineCareDetails = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Salvar") {
                                routineCareViewModel.registerRoutineCare(
                                    date: routineDate, discardedSolution: routineDiscardedSolution,
                                    cleanedCase: routineCleanedCase, airDried: routineAirDried,
                                    notes: routineNotes.isEmpty ? nil : routineNotes, context: modelContext
                                )
                                showRegisterRoutineCareDetails = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
    }

    // MARK: - Em uso

    @ViewBuilder
    private var summaryContent: some View {
        if !inUsePairs.isEmpty {
            AppCard(variant: .featured) {
                SectionHeader("Em uso") {
                    if pairsNeedingUsageToday.isEmpty {
                        StatusBadge(text: "Tudo certo", tone: .success, systemImage: "checkmark.circle.fill")
                    }
                }
                if pairsNeedingUsageToday.count > 1 {
                    registerAllUsageButton
                    Divider()
                }
                ForEach(inUsePairs) { pair in
                    pairActionCard(for: pair)
                    if pair.id != inUsePairs.last?.id {
                        Divider()
                    }
                }
            }
        }
        if !reservePairs.isEmpty {
            ReminderCard(
                systemImage: "tray.and.arrow.down",
                title: "Reservas disponíveis",
                detail: "\(reservePairs.count) par(es)",
                tone: .neutral
            ) {
                router.selectedTab = .lentes
            }
        }
    }

    private func hasUsageToday(_ pair: LensPair) -> Bool {
        LensStatisticsService.hasUsage(onSameDayAs: Date(), in: pair.usages ?? [])
    }

    private var pairsNeedingUsageToday: [LensPair] {
        inUsePairs.filter { !hasUsageToday($0) && !$0.hasReachedLimit }
    }

    private var registerAllUsageButton: some View {
        PrimaryActionButton(
            title: "Registrar uso nos \(pairsNeedingUsageToday.count) pares pendentes",
            systemImage: "checkmark.circle.fill"
        ) {
            pairsViewModel.registerUsageForAllInUsePairs(pairsNeedingUsageToday, settings: settings, context: modelContext)
        }
    }

    private func pairActionCard(for pair: LensPair) -> some View {
        let status = LensStatisticsService.usageStatus(
            usesRemaining: pair.usesRemaining,
            maximumUses: pair.maximumUses,
            goodBelowPercent: settings.healthGoodBelowPercent,
            warningBelowPercent: settings.healthWarningBelowPercent,
            criticalBelowPercent: settings.healthCriticalBelowPercent
        )
        let isWearingHere = pairsViewModel.wearingSessionPairID == pair.id
        let usedToday = hasUsageToday(pair)
        let fraction = pair.maximumUses > 0 ? Double(pair.usesRemaining) / Double(pair.maximumUses) : 0

        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Button {
                router.openPair(pair.id)
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    ZStack {
                        // Traço mais fino que o padrão (14pt) neste anel especificamente: a
                        // 72x72 fixo, o padrão deixaria pouquíssimo espaço interno para duas
                        // linhas de texto — apertado o bastante para sobrepor em Dynamic Type
                        // maior. 7pt libera espaço interno real. 72 (não 84): mesmo tamanho do
                        // anel de "Lembretes", e reduz um pouco o peso vertical do cartão —
                        // "Em uso" é o primeiro cartão da tela, então cada ponto de altura conta
                        // pra deixar mais conteúdo visível antes de rolar.
                        ProgressRingView(remainingFraction: fraction, tint: status.tone.color, lineWidth: 7)
                        VStack(spacing: 0) {
                            Text("\(pair.usesRemaining)")
                                .font(AppTypography.metricValue)
                                .minimumScaleFactor(0.4)
                                .lineLimit(1)
                            Text("restantes")
                                .font(AppTypography.caption)
                                .foregroundStyle(.secondary)
                                // 0.4, tão agressivo quanto o número acima: é texto decorativo
                                // (already `.accessibilityHidden` no pai), então encolher bem
                                // pequeno em Dynamic Type extremo é preferível a truncar com
                                // "…" — confirmado no simulador com "Accessibility Large".
                                .minimumScaleFactor(0.4)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 4)
                    }
                    .frame(width: 72, height: 72)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text(pair.name)
                            .font(AppTypography.headline)
                            .foregroundStyle(.primary)
                        StatusBadge(text: status.label, tone: status.tone, systemImage: "shield.fill")
                        SegmentedProgressBar(filledFraction: fraction, tone: status.tone)
                            .padding(.top, AppSpacing.xxs)
                    }

                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
            .pressScale()
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(pair.name), \(status.label)")
            .accessibilityValue("\(pair.usesRemaining) de \(pair.maximumUses) usos restantes")
            .accessibilityHint("Abre o diário deste par")

            pairActionRow(for: pair, usedToday: usedToday, isWearingHere: isWearingHere)
        }
    }

    /// `ViewThatFits` alterna para empilhado quando os dois botões não cabem lado a lado — nome
    /// de par longo + Dynamic Type grande + tela estreita (iPhone SE) é exatamente esse caso;
    /// truncar o texto do botão em vez de quebrar a linha esconderia a ação, não só o rótulo.
    ///
    /// O candidato horizontal usa filhos de largura natural (`fullWidth: false`), não
    /// `.infinity`: um filho `.infinity` sempre "cabe" pra `ViewThatFits` (sua largura mínima é
    /// pequena mesmo que o conteúdo precise embrulhar depois de layout), o que fazia o
    /// candidato horizontal ser escolhido mesmo quando o texto não ia caber de verdade,
    /// resultando em uma pílula quebrando em duas linhas. Com largura natural, `ViewThatFits`
    /// mede o tamanho real do conteúdo e só cai pro vertical quando genuinamente precisa.
    @ViewBuilder
    private func pairActionRow(for pair: LensPair, usedToday: Bool, isWearingHere: Bool) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppSpacing.sm) {
                pairActionRowContent(for: pair, usedToday: usedToday, isWearingHere: isWearingHere, fullWidth: false)
            }
            .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                pairActionRowContent(for: pair, usedToday: usedToday, isWearingHere: isWearingHere, fullWidth: true)
            }
        }
    }

    @ViewBuilder
    private func pairActionRowContent(for pair: LensPair, usedToday: Bool, isWearingHere: Bool, fullWidth: Bool) -> some View {
        if usedToday {
            StatusBadge(text: "Uso registrado hoje", tone: .success, systemImage: "checkmark.circle.fill", fullWidth: fullWidth)
        } else {
            PrimaryActionButton(title: "Registrar uso hoje", isDisabled: pair.hasReachedLimit, fullWidth: fullWidth) {
                pairsViewModel.registerUsageToday(for: pair, side: pair.side, settings: settings, context: modelContext)
            }
        }
        if pairsViewModel.wearingSessionPairID == nil || isWearingHere {
            // Mesma família de cor (indigo) nos dois estados — a hierarquia vem do estilo
            // preenchido vs. contornado, não de trocar para vermelho; vermelho fica reservado
            // para crítico/destrutivo, e encerrar uma sessão de uso não é nem um nem outro.
            // Preenchido quando é a única ação restante na linha (uso já registrado hoje);
            // contornado quando "Registrar uso hoje" ainda disputa a atenção como ação primária —
            // só um botão preenchido por vez, para não competir consigo mesmo.
            let title = isWearingHere ? "Retirei as lentes" : "Estou usando as lentes"
            if usedToday {
                PrimaryActionButton(title: title, fullWidth: fullWidth) {
                    handleWearingSessionToggle(for: pair)
                }
            } else {
                SecondaryActionButton(title: title, fullWidth: fullWidth) {
                    handleWearingSessionToggle(for: pair)
                }
            }
        }
    }

    private var sessionStartPromptBinding: Binding<Bool> {
        Binding(
            get: { pendingSessionStartPair != nil },
            set: { if !$0 { pendingSessionStartPair = nil } }
        )
    }

    private func handleWearingSessionToggle(for pair: LensPair) {
        if pairsViewModel.wearingSessionPairID == pair.id {
            Task {
                await pairsViewModel.endWearingSession(context: modelContext)
                if !hasRoutineCareToday {
                    showRoutineCarePrompt = true
                }
            }
        } else if hasUsageToday(pair) {
            pairsViewModel.toggleWearingSession(for: pair, settings: settings, context: modelContext)
        } else {
            // Sem uso registrado hoje ainda: pergunta antes de só iniciar a sessão, para não
            // deixar a pessoa esquecer justamente de contabilizar a utilização do dia.
            pendingSessionStartPair = pair
        }
    }

    /// Deliberadamente sem `AppCard` — teria o mesmo peso visual das ações principais. Isto é
    /// uma confirmação silenciosa, não mais um cartão para competir por atenção.
    private var everythingSettledRow: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppColor.success)
                .accessibilityHidden(true)
            Text("Você está com tudo em dia.")
                .font(AppTypography.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.xs)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Lembretes

    /// Identidade estável por tipo de lembrete — usar `UUID()` recalculado a cada renderização
    /// faria o SwiftUI tratar cada atualização como uma lista inteiramente nova, prejudicando
    /// animações e a preservação de estado da lista.
    private enum ReminderKind: Hashable {
        case lensCase, solution, appointment, inventory
    }

    private struct ReminderItem: Identifiable {
        let id: ReminderKind
        let icon: String
        let title: String
        let detail: String
        let tab: AppTab
        /// `nil` quando o lembrete não tem uma contagem de dias própria (ex.: estoque, que é uma
        /// contagem de caixas) — nesse caso ele nunca vira o item em destaque com anel.
        var daysRemaining: Int? = nil
        var tone: AppStatusTone = .informative
    }

    /// Mais urgente primeiro (menor `daysRemaining`), para que o item em destaque do cartão seja
    /// sempre o que precisa de mais atenção, não só o primeiro por ordem de inserção.
    private var reminderItems: [ReminderItem] {
        var items: [ReminderItem] = []
        if let activeCase {
            let days = LensStatisticsService.daysUntil(activeCase.nextRecommendedReplacementDate)
            items.append(ReminderItem(id: .lensCase, icon: "shippingbox", title: "Estojo", detail: caseReminderDetail(activeCase), tab: .cuidados, daysRemaining: days, tone: reminderTone(daysRemaining: days)))
        }
        if let activeSolution {
            let days = LensStatisticsService.daysUntil(activeSolution.discardDate)
            items.append(ReminderItem(id: .solution, icon: "flask", title: "Solução", detail: solutionReminderDetail(activeSolution), tab: .cuidados, daysRemaining: days, tone: reminderTone(daysRemaining: days)))
        }
        if let nextAppointment {
            let days = LensStatisticsService.daysUntil(nextAppointment.date)
            items.append(ReminderItem(id: .appointment, icon: "stethoscope", title: "Consulta", detail: appointmentReminderDetail(nextAppointment), tab: .consultas, daysRemaining: days, tone: reminderTone(daysRemaining: days)))
        }
        if !expiringInventoryItems.isEmpty {
            items.append(ReminderItem(id: .inventory, icon: "tray.full", title: "Estoque", detail: inventoryReminderDetail, tab: .lentes, tone: .warning))
        }
        return items.sorted { lhs, rhs in
            switch (lhs.daysRemaining, rhs.daysRemaining) {
            case let (l?, r?): return l < r
            case (nil, _): return false
            case (_, nil): return true
            }
        }
    }

    private func reminderTone(daysRemaining: Int) -> AppStatusTone {
        if daysRemaining <= 0 { return .critical }
        if daysRemaining <= settings.advanceReminderDays { return .warning }
        return .informative
    }

    /// O primeiro item (o mais urgente, após a ordenação acima) ganha o tratamento em destaque
    /// com anel quando tem uma contagem de dias própria; os demais continuam como linha simples —
    /// nenhuma informação é perdida, só o mais urgente ganha mais peso visual.
    private var remindersCard: some View {
        AppCard {
            SectionHeader("Lembretes")
            ForEach(Array(reminderItems.enumerated()), id: \.element.id) { index, item in
                if index == 0, let days = item.daysRemaining {
                    FeaturedReminderRow(
                        systemImage: item.icon,
                        title: item.title,
                        detail: item.detail,
                        ringValue: "\(abs(days))",
                        ringFraction: min(max(Double(days) / 90, 0), 1),
                        tone: item.tone
                    ) {
                        router.selectedTab = item.tab
                    }
                } else {
                    ReminderCard(systemImage: item.icon, title: item.title, detail: item.detail, tone: item.tone) {
                        router.selectedTab = item.tab
                    }
                }
                if index != reminderItems.count - 1 {
                    Divider()
                }
            }
        }
    }

    private func caseReminderDetail(_ lensCase: LensCase) -> String {
        let days = LensStatisticsService.daysUntil(lensCase.nextRecommendedReplacementDate)
        if days > 0 { return "Substituição recomendada em \(days) dia(s)" }
        if days == 0 { return "Substituição recomendada para hoje" }
        return "Substituição recomendada há \(-days) dia(s)"
    }

    private func solutionReminderDetail(_ solution: CleaningSolution) -> String {
        let days = LensStatisticsService.daysUntil(solution.discardDate)
        if days > 0 { return "Descarte recomendado em \(days) dia(s)" }
        if days == 0 { return "Descarte recomendado para hoje" }
        return "Descarte recomendado há \(-days) dia(s)"
    }

    private func appointmentReminderDetail(_ appointment: EyeAppointment) -> String {
        let dateText = DateFormatting.short.string(from: appointment.date)
        if let name = appointment.professional?.name {
            return "\(dateText) com \(name)"
        }
        return dateText
    }

    private var inventoryReminderDetail: String {
        expiringInventoryItems.count == 1 ? "1 caixa perto da validade" : "\(expiringInventoryItems.count) caixas perto da validade"
    }

    /// Encerra a sessão de uso ativa quando o usuário toca "Retirei agora" numa notificação —
    /// a sessão em si já foi encerrada no banco por `NotificationManager`; isto só sincroniza o
    /// estado local (`wearingSessionPairID`) e funciona mesmo que o app tenha sido reaberto do
    /// zero por causa do toque.
    private func endPendingWearingSessionIfNeeded() async {
        guard router.pendingEndWearingSession else { return }
        router.pendingEndWearingSession = false
        await pairsViewModel.endWearingSession(context: modelContext)
    }
}

#Preview {
    HomeView()
        .modelContainer(PreviewData.container)
}
