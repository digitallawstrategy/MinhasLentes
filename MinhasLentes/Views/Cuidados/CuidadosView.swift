import SwiftUI
import SwiftData

/// Aba Cuidados: ponto de entrada para Estojo e Solução de limpeza — os dois cuidados do
/// material físico das lentes, agrupados aqui para não disputar espaço na barra de abas com
/// Lentes e Consultas, que são destinos usados com mais frequência.
struct CuidadosView: View {
    @Query(sort: \LensCase.startDate, order: .reverse) private var cases: [LensCase]
    @Query(sort: \CleaningSolution.openedDate, order: .reverse) private var solutions: [CleaningSolution]

    private var activeCase: LensCase? { cases.first { $0.status == .active } }
    private var activeSolution: CleaningSolution? { solutions.first { $0.status == .active } }

    private var caseDetail: String {
        guard let activeCase else { return "Nenhum ciclo iniciado ainda" }
        let days = LensStatisticsService.daysUntil(activeCase.nextRecommendedReplacementDate)
        return days <= 0 ? "Substituição recomendada já se aproximou" : "Substituição recomendada em \(days) dia(s)"
    }

    private var solutionDetail: String {
        guard let activeSolution else { return "Nenhum frasco registrado ainda" }
        let days = LensStatisticsService.daysUntil(activeSolution.discardDate)
        return days <= 0 ? "Validade recomendada já se aproximou" : "Descarte recomendado em \(days) dia(s)"
    }

    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    CaseView()
                } label: {
                    row(icon: "shippingbox", title: "Estojo", detail: caseDetail)
                }
                NavigationLink {
                    CleaningSolutionView()
                } label: {
                    row(icon: "flask", title: "Solução de limpeza", detail: solutionDetail)
                }
            }
            .navigationTitle("Cuidados")
        }
    }

    private func row(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    CuidadosView()
        .modelContainer(PreviewData.container)
}
