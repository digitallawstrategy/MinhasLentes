import SwiftUI

/// Formulário para iniciar um novo par (ou lado) de lentes. Se houver itens disponíveis no
/// estoque compatíveis com o lado escolhido, oferece a opção de usar um deles — o que reduz a
/// quantidade restante automaticamente ao confirmar.
struct StartNewPairSheet: View {
    let defaultMaximumUses: Int
    let availableSides: [LensSide]
    let availableInventoryItems: [LensInventoryItem]
    let onConfirm: (
        _ name: String?, _ startDate: Date, _ maximumUses: Int, _ side: LensSide, _ asReserve: Bool,
        _ inventoryItem: LensInventoryItem?
    ) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var startDate = Date()
    @State private var maximumUses: Int
    @State private var side: LensSide
    @State private var asReserve = false
    @State private var useInventoryItem = false
    @State private var selectedInventoryItemID: UUID?
    @State private var showExpiredInventoryWarning = false

    init(
        defaultMaximumUses: Int,
        availableSides: [LensSide],
        availableInventoryItems: [LensInventoryItem] = [],
        onConfirm: @escaping (String?, Date, Int, LensSide, Bool, LensInventoryItem?) -> Void
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
                        Toggle("Deseja utilizar uma lente do estoque?", isOn: $useInventoryItem)
                        if useInventoryItem {
                            Picker("Item do estoque", selection: $selectedInventoryItemID) {
                                Text("Selecione").tag(UUID?.none)
                                ForEach(matchingInventoryItems) { item in
                                    Text("\(item.brand) \(item.model) — \(Pluralization.count(item.remainingQuantity, "restante", "restantes"))\(item.isExpired ? " (vencida)" : "")")
                                        .tag(Optional(item.id))
                                }
                            }
                        }
                    } footer: {
                        Text("Ao confirmar, uma unidade é descontada automaticamente do estoque.")
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
                        if useInventoryItem, let item = selectedInventoryItem, item.isExpired {
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
            useInventoryItem ? selectedInventoryItem : nil
        )
        dismiss()
    }
}
