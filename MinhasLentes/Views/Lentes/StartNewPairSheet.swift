import SwiftUI

/// Formulário para iniciar um novo par (ou lado) de lentes. Se houver itens disponíveis no
/// estoque compatíveis com o lado escolhido, oferece a opção de usar um deles — o que reduz a
/// quantidade restante automaticamente ao confirmar.
struct StartNewPairSheet: View {
    /// Como o par de dois olhos vai descontar do estoque: uma caixa `.both` supre os dois
    /// (consome 2 dela) ou uma caixa por olho (consome 1 de cada).
    private enum BothConsumptionMode: String, CaseIterable, Identifiable {
        case singleBox = "Uma caixa para os dois"
        case separateBoxes = "Caixa separada por olho"
        var id: String { rawValue }
    }

    let defaultMaximumUses: Int
    let availableSides: [LensSide]
    let availableInventoryItems: [LensInventoryItem]
    let onConfirm: (
        _ name: String?, _ startDate: Date, _ maximumUses: Int, _ side: LensSide, _ asReserve: Bool,
        _ inventorySelections: [LensInventoryService.ConsumptionSelection]
    ) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var startDate = Date()
    @State private var maximumUses: Int
    @State private var side: LensSide
    @State private var asReserve = false
    @State private var useInventoryItem = false
    @State private var selectedInventoryItemID: UUID?
    @State private var bothMode: BothConsumptionMode = .separateBoxes
    @State private var selectedSingleBoxItemID: UUID?
    @State private var selectedRightItemID: UUID?
    @State private var selectedLeftItemID: UUID?
    @State private var showExpiredInventoryWarning = false

    init(
        defaultMaximumUses: Int,
        availableSides: [LensSide],
        availableInventoryItems: [LensInventoryItem] = [],
        onConfirm: @escaping (String?, Date, Int, LensSide, Bool, [LensInventoryService.ConsumptionSelection]) -> Void
    ) {
        self.defaultMaximumUses = defaultMaximumUses
        self.availableSides = availableSides.isEmpty ? [.both] : availableSides
        self.availableInventoryItems = availableInventoryItems
        self.onConfirm = onConfirm
        _maximumUses = State(initialValue: defaultMaximumUses)
        _side = State(initialValue: availableSides.first ?? .both)
    }

    private var matchingInventoryItems: [LensInventoryItem] {
        availableInventoryItems.filter { $0.side == side || $0.side == .both || side == .both }
    }

    private var selectedInventoryItem: LensInventoryItem? {
        matchingInventoryItems.first { $0.id == selectedInventoryItemID }
    }

    /// Elegíveis para "uma caixa para os dois": precisa ser `.both` e ter saldo para 2 unidades.
    private var bothEligibleSingleBoxItems: [LensInventoryItem] {
        availableInventoryItems.filter { $0.side == .both && $0.remainingQuantity >= 2 }
    }

    private var rightEligibleItems: [LensInventoryItem] {
        availableInventoryItems.filter { $0.side == .right || $0.side == .both }
    }

    private var leftEligibleItems: [LensInventoryItem] {
        availableInventoryItems.filter { $0.side == .left || $0.side == .both }
    }

    private var selectedSingleBoxItem: LensInventoryItem? {
        bothEligibleSingleBoxItems.first { $0.id == selectedSingleBoxItemID }
    }

    private var selectedRightItem: LensInventoryItem? {
        rightEligibleItems.first { $0.id == selectedRightItemID }
    }

    private var selectedLeftItem: LensInventoryItem? {
        leftEligibleItems.first { $0.id == selectedLeftItemID }
    }

    /// O que será de fato descontado do estoque ao confirmar — a mesma lista alimenta o resumo
    /// mostrado na tela e a chamada de `onConfirm`, para nunca haver divergência entre o que o
    /// usuário vê e o que é gravado.
    private var inventorySelections: [LensInventoryService.ConsumptionSelection] {
        guard useInventoryItem else { return [] }
        if side == .both {
            switch bothMode {
            case .singleBox:
                guard let item = selectedSingleBoxItem else { return [] }
                return [LensInventoryService.ConsumptionSelection(item: item, quantity: 2)]
            case .separateBoxes:
                var selections: [LensInventoryService.ConsumptionSelection] = []
                if let right = selectedRightItem {
                    selections.append(LensInventoryService.ConsumptionSelection(item: right, quantity: 1))
                }
                if let left = selectedLeftItem {
                    selections.append(LensInventoryService.ConsumptionSelection(item: left, quantity: 1))
                }
                return selections
            }
        } else {
            guard let item = selectedInventoryItem else { return [] }
            return [LensInventoryService.ConsumptionSelection(item: item, quantity: 1)]
        }
    }

    private var deductionSummaryText: String? {
        guard !inventorySelections.isEmpty else { return nil }
        let parts = inventorySelections.map { selection in
            "\(Pluralization.count(selection.quantity, "unidade", "unidades")) de \(selection.item.brand) \(selection.item.model)"
        }
        return "Vai descontar: \(parts.joined(separator: " e "))."
    }

    private var anySelectedItemExpired: Bool {
        inventorySelections.contains { $0.item.isExpired }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nome (opcional)", text: $name)
                    DatePicker("Data de início", selection: $startDate, displayedComponents: .date)
                    Stepper("Limite de usos: \(maximumUses)", value: $maximumUses, in: 1...500)

                    if availableSides.count > 1 {
                        Picker("Lado", selection: $side) {
                            ForEach(availableSides) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                    } else if let only = availableSides.first, only != .both {
                        LabeledContent("Lado", value: only.displayName)
                    }
                } header: {
                    Text("Novo par")
                } footer: {
                    Text("Se nenhum nome for informado, o par receberá uma identificação automática.")
                }

                if !matchingInventoryItems.isEmpty {
                    Section {
                        Toggle(
                            side == .both ? "Deseja utilizar lentes do estoque?" : "Deseja utilizar uma lente do estoque?",
                            isOn: $useInventoryItem
                        )
                        if useInventoryItem {
                            if side == .both {
                                Picker("Como descontar", selection: $bothMode) {
                                    ForEach(BothConsumptionMode.allCases) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)

                                switch bothMode {
                                case .singleBox:
                                    Picker("Caixa (2 unidades)", selection: $selectedSingleBoxItemID) {
                                        Text("Selecione").tag(UUID?.none)
                                        ForEach(bothEligibleSingleBoxItems) { item in
                                            inventoryItemLabel(item)
                                                .tag(Optional(item.id))
                                        }
                                    }
                                case .separateBoxes:
                                    Picker("Caixa direita (OD)", selection: $selectedRightItemID) {
                                        Text("Selecione").tag(UUID?.none)
                                        ForEach(rightEligibleItems) { item in
                                            inventoryItemLabel(item)
                                                .tag(Optional(item.id))
                                        }
                                    }
                                    Picker("Caixa esquerda (OE)", selection: $selectedLeftItemID) {
                                        Text("Selecione").tag(UUID?.none)
                                        ForEach(leftEligibleItems) { item in
                                            inventoryItemLabel(item)
                                                .tag(Optional(item.id))
                                        }
                                    }
                                }
                            } else {
                                Picker("Item do estoque", selection: $selectedInventoryItemID) {
                                    Text("Selecione").tag(UUID?.none)
                                    ForEach(matchingInventoryItems) { item in
                                        inventoryItemLabel(item)
                                            .tag(Optional(item.id))
                                    }
                                }
                            }
                            if let deductionSummaryText {
                                Text(deductionSummaryText)
                                    .font(AppTypography.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } footer: {
                        Text(
                            side == .both
                                ? "Ao confirmar, as unidades escolhidas são descontadas automaticamente do estoque."
                                : "Ao confirmar, uma unidade é descontada automaticamente do estoque."
                        )
                    }
                }

                Section {
                    Toggle("Guardar como reserva", isOn: $asReserve)
                } footer: {
                    Text(
                        asReserve
                            ? "Fica disponível para ativar depois, sem afetar o par que já está em uso neste lado."
                            : "Passa a ser o par em uso deste lado agora — se já houver outro em uso, ele é movido para reserva (não é encerrado)."
                    )
                }
            }
            .navigationTitle("Iniciar novo par")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Iniciar") {
                        if useInventoryItem && anySelectedItemExpired {
                            showExpiredInventoryWarning = true
                        } else {
                            confirm()
                        }
                    }
                }
            }
            .alert(
                "Esta lente está com a validade vencida",
                isPresented: $showExpiredInventoryWarning
            ) {
                Button("Cancelar", role: .cancel) {}
                Button("Usar mesmo assim", role: .destructive) {
                    confirm()
                }
            } message: {
                Text("A data de validade indicada para este item do estoque já passou. Deseja usá-la mesmo assim?")
            }
        }
    }

    private func confirm() {
        onConfirm(
            name.isEmpty ? nil : name, startDate, maximumUses, side, asReserve,
            inventorySelections
        )
        dismiss()
    }

    private func inventoryItemLabel(_ item: LensInventoryItem) -> Text {
        Text("\(item.brand) \(item.model) — \(Pluralization.count(item.remainingQuantity, "restante", "restantes"))\(item.isExpired ? " (vencida)" : "")")
    }
}
