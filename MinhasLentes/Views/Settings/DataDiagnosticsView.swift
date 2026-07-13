import SwiftUI
import SwiftData
import UIKit

#if DEBUG
/// Tela de diagnóstico — só existe em build DEBUG, nunca compila em Release. Mostra contagens
/// de cada modelo persistido e a identificação do app/App Group/store, para comparar o estado
/// real do armazenamento no aparelho antes e depois de um novo "Run" pelo Xcode, sem depender de
/// leitura indireta pela UI normal (calendário, cartões da Home), que já passou por lógica de
/// apresentação própria.
///
/// Lê `modelContext` normalmente — o mesmo `AppContainer.shared()` que o resto do app usa. Nunca
/// abre um store à parte, então o que aparece aqui é exatamente o que a Home/Cuidados também
/// veem, no mesmo processo, no mesmo lançamento.
///
/// Checklist manual para diferenciar as 4 causas possíveis se `RoutineCareLog` sumir depois de
/// um novo Run:
/// 1. Instalar no iPhone (Run pelo Xcode). Registrar 7 cuidados diários em dias diferentes.
/// 2. Abrir esta tela, tocar "Copiar diagnóstico", colar em algum lugar seguro (Notas, por ex.).
/// 3. Rodar Run de novo pelo Xcode, SEM apagar o app do aparelho manualmente antes.
/// 4. Abrir esta tela de novo, comparar com o diagnóstico anotado no passo 2:
///    - `RoutineCareLog` continua 7, Bundle Identifier e Store iguais → tudo certo, era outra
///      causa (ex.: um bug na leitura da View, não no armazenamento).
///    - `RoutineCareLog` virou 0, mas Bundle Identifier e Store (caminho) continuam
///      IDÊNTICOS → o arquivo no mesmo caminho foi substituído/recriado vazio — aponta para
///      reinstalação completa (delete + install) em vez de upgrade incremental.
///    - `RoutineCareLog` virou 0 E o caminho do Store mudou → o contêiner do App Group em si
///      mudou de lugar — aponta para mudança de assinatura/provisioning/team, não só
///      reinstalação.
///    - Bundle Identifier mudou → causa já conhecida e documentada em Configurações
///      ("persistenceInfoSection"): Bundle ID diferente sempre cria um contêiner novo.
struct DataDiagnosticsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var didCopy = false

    private struct ModelCount: Identifiable {
        let id: String
        let label: String
        let value: Int?
    }

    private var counts: [ModelCount] {
        [
            ModelCount(id: "LensPair", label: "LensPair", value: try? modelContext.fetchCount(FetchDescriptor<LensPair>())),
            ModelCount(id: "LensUsage", label: "LensUsage", value: try? modelContext.fetchCount(FetchDescriptor<LensUsage>())),
            ModelCount(id: "RoutineCareLog", label: "RoutineCareLog", value: try? modelContext.fetchCount(FetchDescriptor<RoutineCareLog>())),
            ModelCount(id: "CaseCleaning", label: "CaseCleaning", value: try? modelContext.fetchCount(FetchDescriptor<CaseCleaning>())),
            ModelCount(id: "LensCase", label: "LensCase", value: try? modelContext.fetchCount(FetchDescriptor<LensCase>())),
            ModelCount(id: "CleaningSolution", label: "CleaningSolution", value: try? modelContext.fetchCount(FetchDescriptor<CleaningSolution>())),
            ModelCount(id: "HistoryEvent", label: "HistoryEvent", value: try? modelContext.fetchCount(FetchDescriptor<HistoryEvent>())),
        ]
    }

    private var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "desconhecido"
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (build \(build))"
    }

    /// Caminho completo, não só "existe ou não" — é o que permite comparar entre duas execuções
    /// se o contêiner do App Group é literalmente o mesmo diretório ou um novo.
    private var storePath: String {
        do {
            return try AppGroup.storeURL().path
        } catch {
            return "Indisponível: \(error.localizedDescription)"
        }
    }

    private var diagnosticsText: String {
        var lines = [
            "Diagnóstico de dados — Minhas Lentes",
            "Gerado em \(DateFormatting.shortWithTime.string(from: Date()))",
            "",
            "Bundle Identifier: \(bundleIdentifier)",
            "App Group: \(AppGroup.identifier)",
            "Versão/build: \(appVersion)",
            "Store: \(storePath)",
            "",
        ]
        for count in counts {
            lines.append("\(count.label): \(count.value.map(String.init) ?? "erro ao ler")")
        }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        Form {
            Section("Contagens") {
                ForEach(counts) { count in
                    LabeledContent(count.label, value: count.value.map(String.init) ?? "erro")
                }
            }
            Section("Identificação") {
                LabeledContent("Bundle Identifier", value: bundleIdentifier)
                LabeledContent("App Group", value: AppGroup.identifier)
                LabeledContent("Versão/build", value: appVersion)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Store (MinhasLentes.sqlite)")
                    Text(storePath)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                Button {
                    UIPasteboard.general.string = diagnosticsText
                    didCopy = true
                } label: {
                    Label("Copiar diagnóstico", systemImage: "doc.on.doc")
                }
                if didCopy {
                    Text("Copiado para a área de transferência.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("Visível apenas em builds DEBUG. Lê o mesmo armazenamento que o resto do app usa neste lançamento — não abre nenhum arquivo à parte.")
            }
        }
        .navigationTitle("Diagnóstico de dados")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        DataDiagnosticsView()
            .modelContainer(PreviewData.container)
    }
}
#endif
