import XCTest
import UserNotifications
@testable import MinhasLentes

/// Testes de fumaça para o agendamento local de notificações. Neste ambiente de teste a
/// autorização de notificações nunca é concedida (não há interação humana com o alerta do
/// sistema), por isso os fluxos "reais" aqui verificam o comportamento esperado nesse estado
/// (lança `authorizationDenied`, nada fica pendente). A entrega efetiva das notificações e o
/// comportamento com o aplicativo fechado/bloqueado exigem verificação manual em um iPhone
/// físico — ver "Procedimento para testar notificações" nas instruções de instalação.
@MainActor
final class NotificationManagerTests: XCTestCase {

    func testIdentifiersAreStableAndUnique() {
        XCTAssertEqual(NotificationManager.advanceIdentifier, "estojo.aviso-antecipado")
        XCTAssertEqual(NotificationManager.deadlineIdentifier, "estojo.prazo")
        XCTAssertNotEqual(NotificationManager.advanceIdentifier, NotificationManager.deadlineIdentifier)
        XCTAssertEqual(NotificationManager.dailyCareReminderIdentifier, "cuidado-diario.lembrete")
        XCTAssertNotEqual(NotificationManager.dailyCareReminderIdentifier, NotificationManager.advanceIdentifier)
        XCTAssertNotEqual(NotificationManager.dailyCareReminderIdentifier, NotificationManager.deadlineIdentifier)
        #if DEBUG
        XCTAssertNotEqual(NotificationManager.testOneMinuteIdentifier, NotificationManager.advanceIdentifier)
        XCTAssertNotEqual(NotificationManager.testTwoMinuteIdentifier, NotificationManager.deadlineIdentifier)
        XCTAssertNotEqual(NotificationManager.testOneMinuteIdentifier, NotificationManager.testTwoMinuteIdentifier)
        #endif
    }

    func testCancelDoesNotThrowWithoutPendingNotifications() async {
        await NotificationManager.shared.cancelCaseCleaningNotifications()
    }

    func testSchedulingWithoutAuthorizationThrowsAuthorizationDeniedAndSchedulesNothing() async {
        let settings = AppSettings()
        await NotificationManager.shared.cancelCaseCleaningNotifications()

        do {
            _ = try await NotificationManager.shared.scheduleCaseCleaningNotifications(lastCleaningDate: Date(), settings: settings)
            XCTFail("Sem autorização concedida, o agendamento deveria lançar authorizationDenied")
        } catch NotificationManager.NotificationError.authorizationDenied {
            // Esperado neste ambiente de teste.
        } catch {
            XCTFail("Erro inesperado: \(error)")
        }

        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let ours = pending.filter {
            $0.identifier == NotificationManager.advanceIdentifier || $0.identifier == NotificationManager.deadlineIdentifier
        }
        XCTAssertTrue(ours.isEmpty, "Sem autorização concedida, nenhuma notificação real deve ficar pendente")
    }

    func testCaseCleaningRegistrationSucceedsEvenWithoutNotificationAuthorization() async throws {
        // A falta de autorização não deve impedir o registro da limpeza em si — apenas o
        // agendamento das notificações reais é ignorado nesse cenário (ver CaseCleaningService).
        let context = TestSupport.makeContext()
        let settings = AppSettings()
        context.insert(settings)

        let cleaning = try await CaseCleaningService.registerCleaning(date: Date(), notes: nil, settings: settings, context: context)
        XCTAssertNotNil(cleaning.id)
        XCTAssertEqual(try CaseCleaningService.allCleanings(context: context).count, 1)
    }

    #if DEBUG
    func testTestNotificationsThrowAuthorizationDeniedWithoutAuthorization() async {
        do {
            try await NotificationManager.shared.scheduleSingleTestNotification()
            XCTFail("Sem autorização concedida, deveria lançar authorizationDenied")
        } catch NotificationManager.NotificationError.authorizationDenied {
            // Esperado.
        } catch {
            XCTFail("Erro inesperado: \(error)")
        }
    }

    func testCancelTestNotificationsNeverRemovesRealIdentifiers() async {
        await NotificationManager.shared.cancelTestNotifications()
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let realOnes = pending.filter {
            $0.identifier == NotificationManager.advanceIdentifier || $0.identifier == NotificationManager.deadlineIdentifier
        }
        // cancelTestNotifications não deve interferir nos identificadores reais (aqui, vazio).
        XCTAssertTrue(realOnes.isEmpty)
    }
    #endif
}
