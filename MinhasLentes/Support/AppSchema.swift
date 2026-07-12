import Foundation
import SwiftData

/// Schema versionado do armazenamento principal — existe como seguro contra o tipo de perda de
/// dado que já aconteceu uma vez neste projeto (ver `AppGroup.migrateLegacyStoreIfNeeded`, que
/// corrigiu o armazenamento "sumindo" ao mover para o App Group). Aquele caso era de *local* do
/// arquivo; este aqui cobre o outro caso possível — mudança de *forma* do schema. Sem nenhum
/// `SchemaMigrationPlan`, qualquer mudança futura não aditiva num `@Model` (renomear campo,
/// trocar tipo, remover propriedade) fica por conta da migração automática do SwiftData
/// inferir sozinha — quando ela erra, o efeito visível pro usuário é exatamente "meus dados
/// sumiram depois de atualizar o app".
///
/// Hoje isto é só a base (`AppSchemaV1`, idêntico ao schema já em uso, zero estágios de
/// migração) — não muda nenhum comportamento agora. O valor está em existir *antes* de a
/// próxima mudança de modelo precisar de uma migração de verdade: nesse dia, alguém cria
/// `AppSchemaV2` e um `MigrationStage.custom`/`.lightweight` explícito, em vez de torcer para a
/// inferência automática acertar.
enum AppSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            LensPair.self,
            LensUsage.self,
            CaseCleaning.self,
            AppSettings.self,
            HistoryEvent.self,
            LensCase.self,
            RoutineCareLog.self,
            CleaningSolution.self,
            LensInventoryItem.self,
            EyeCareProfessional.self,
            EyeAppointment.self,
            WearSession.self,
        ]
    }
}

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [AppSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
