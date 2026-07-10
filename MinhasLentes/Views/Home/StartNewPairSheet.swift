import SwiftUI

/// Formulário para iniciar um novo par (ou lado) de lentes.
struct StartNewPairSheet: View {
    let defaultMaximumUses: Int
    let availableSides: [LensSide]
    let onConfirm: (_ name: String?, _ startDate: Date, _ maximumUses: Int, _ side: LensSide, _ asReserve: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var startDate = Date()
    @State private var maximumUses: Int
    @State private var side: LensSide
    @State private var asReserve = false

    init(
        defaultMaximumUses: Int,
        availableSides: [LensSide],
        onConfirm: @escaping (String?, Date, Int, LensSide, Bool) -> Void
    ) {
        self.defaultMaximumUses = defaultMaximumUses
        self.availableSides = availableSides.isEmpty ? [.both] : availableSides
        self.onConfirm = onConfirm
        _maximumUses = State(initialValue: defaultMaximumUses)
        _side = State(initialValue: availableSides.first ?? .both)
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
                        onConfirm(name.isEmpty ? nil : name, startDate, maximumUses, side, asReserve)
                        dismiss()
                    }
                }
            }
        }
    }
}
