import XCTest
import SwiftData
@testable import MinhasLentes

@MainActor
final class EyeCareProfessionalServiceTests: XCTestCase {
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        context = TestSupport.makeContext()
    }

    override func tearDown() {
        context = nil
        super.tearDown()
    }

    func testAddProfessionalCreatesEntry() throws {
        let professional = try EyeCareProfessionalService.addProfessional(
            name: "Dra. Ana", clinic: "Clínica Visão", phone: "11999999999", whatsapp: "11999999999",
            email: "ana@example.com", address: "Rua X, 100", notes: nil, context: context
        )
        XCTAssertEqual(try EyeCareProfessionalService.allProfessionals(context: context).count, 1)
        XCTAssertEqual(professional.name, "Dra. Ana")
    }

    func testEditProfessionalUpdatesFields() throws {
        let professional = try EyeCareProfessionalService.addProfessional(
            name: "Dra. Ana", clinic: nil, phone: nil, whatsapp: nil, email: nil, address: nil, notes: nil, context: context
        )
        try EyeCareProfessionalService.editProfessional(
            professional, name: "Dra. Ana Souza", clinic: "Nova Clínica", phone: "11988888888",
            whatsapp: nil, email: nil, address: nil, notes: "Prefere manhã", context: context
        )
        XCTAssertEqual(professional.name, "Dra. Ana Souza")
        XCTAssertEqual(professional.clinic, "Nova Clínica")
        XCTAssertEqual(professional.notes, "Prefere manhã")
    }

    func testDeleteProfessionalRemovesItButKeepsAppointmentHistory() async throws {
        let professional = try EyeCareProfessionalService.addProfessional(
            name: "Dra. Ana", clinic: nil, phone: nil, whatsapp: nil, email: nil, address: nil, notes: nil, context: context
        )
        let settings = AppSettings()
        context.insert(settings)
        let appointment = try await EyeAppointmentService.scheduleAppointment(
            date: Date().addingTimeInterval(86400 * 30), type: .routine, notes: nil, prescription: nil,
            attachmentData: nil, recommendedFollowUpMonths: 12, professional: professional, settings: settings, context: context
        )

        try EyeCareProfessionalService.deleteProfessional(professional, context: context)

        XCTAssertEqual(try EyeCareProfessionalService.allProfessionals(context: context).count, 0)
        XCTAssertEqual(try EyeAppointmentService.allAppointments(context: context).count, 1)
        XCTAssertNil(appointment.professional, "Excluir o profissional deve apenas desfazer o vínculo, nunca apagar a consulta")
    }
}

@MainActor
final class EyeAppointmentServiceTests: XCTestCase {
    var context: ModelContext!
    var settings: AppSettings!

    override func setUp() {
        super.setUp()
        context = TestSupport.makeContext()
        settings = AppSettings()
        context.insert(settings)
    }

    override func tearDown() {
        context = nil
        settings = nil
        super.tearDown()
    }

    func testScheduleAppointmentCreatesScheduledEntry() async throws {
        let appointment = try await EyeAppointmentService.scheduleAppointment(
            date: Date().addingTimeInterval(86400 * 10), type: .routine, notes: nil, prescription: nil,
            attachmentData: nil, recommendedFollowUpMonths: 12, professional: nil, settings: settings, context: context
        )
        XCTAssertEqual(appointment.status, .scheduled)
        XCTAssertEqual(try EyeAppointmentService.allAppointments(context: context).count, 1)
    }

    func testMultipleAppointmentsCanBeScheduledSimultaneously() async throws {
        _ = try await EyeAppointmentService.scheduleAppointment(
            date: Date().addingTimeInterval(86400 * 10), type: .routine, notes: nil, prescription: nil,
            attachmentData: nil, recommendedFollowUpMonths: 12, professional: nil, settings: settings, context: context
        )
        _ = try await EyeAppointmentService.scheduleAppointment(
            date: Date().addingTimeInterval(86400 * 40), type: .followUp, notes: nil, prescription: nil,
            attachmentData: nil, recommendedFollowUpMonths: 12, professional: nil, settings: settings, context: context
        )
        XCTAssertEqual(try EyeAppointmentService.allAppointments(context: context).count, 2)
    }

    func testNextAppointmentReturnsEarliestScheduledFutureOne() async throws {
        _ = try await EyeAppointmentService.scheduleAppointment(
            date: Date().addingTimeInterval(86400 * 40), type: .routine, notes: nil, prescription: nil,
            attachmentData: nil, recommendedFollowUpMonths: 12, professional: nil, settings: settings, context: context
        )
        let closer = try await EyeAppointmentService.scheduleAppointment(
            date: Date().addingTimeInterval(86400 * 10), type: .followUp, notes: nil, prescription: nil,
            attachmentData: nil, recommendedFollowUpMonths: 12, professional: nil, settings: settings, context: context
        )
        let next = try EyeAppointmentService.nextAppointment(context: context)
        XCTAssertEqual(next?.id, closer.id)
    }

    func testMarkCompletedChangesStatusAndExcludesFromNextAppointment() async throws {
        let appointment = try await EyeAppointmentService.scheduleAppointment(
            date: Date().addingTimeInterval(86400 * 10), type: .routine, notes: nil, prescription: nil,
            attachmentData: nil, recommendedFollowUpMonths: 12, professional: nil, settings: settings, context: context
        )
        try await EyeAppointmentService.markCompleted(appointment, context: context)
        XCTAssertEqual(appointment.status, .completed)
        XCTAssertNil(try EyeAppointmentService.nextAppointment(context: context))
        XCTAssertEqual(try EyeAppointmentService.lastAppointment(context: context)?.id, appointment.id)
    }

    func testCancelAppointmentChangesStatus() async throws {
        let appointment = try await EyeAppointmentService.scheduleAppointment(
            date: Date().addingTimeInterval(86400 * 10), type: .routine, notes: nil, prescription: nil,
            attachmentData: nil, recommendedFollowUpMonths: 12, professional: nil, settings: settings, context: context
        )
        try await EyeAppointmentService.cancelAppointment(appointment, context: context)
        XCTAssertEqual(appointment.status, .canceled)
        XCTAssertNil(try EyeAppointmentService.nextAppointment(context: context))
    }

    func testDeleteAppointmentRemovesIt() async throws {
        let appointment = try await EyeAppointmentService.scheduleAppointment(
            date: Date().addingTimeInterval(86400 * 10), type: .routine, notes: nil, prescription: nil,
            attachmentData: nil, recommendedFollowUpMonths: 12, professional: nil, settings: settings, context: context
        )
        try await EyeAppointmentService.deleteAppointment(appointment, context: context)
        XCTAssertEqual(try EyeAppointmentService.allAppointments(context: context).count, 0)
    }

    func testEditAppointmentUpdatesFields() async throws {
        let appointment = try await EyeAppointmentService.scheduleAppointment(
            date: Date().addingTimeInterval(86400 * 10), type: .routine, notes: nil, prescription: nil,
            attachmentData: nil, recommendedFollowUpMonths: 12, professional: nil, settings: settings, context: context
        )
        let newDate = Date().addingTimeInterval(86400 * 20)
        try await EyeAppointmentService.editAppointment(
            appointment, date: newDate, type: .followUp, notes: "Trazer óculos antigos", prescription: nil,
            attachmentData: nil, recommendedFollowUpMonths: 6, professional: nil, settings: settings, context: context
        )
        XCTAssertEqual(appointment.type, .followUp)
        XCTAssertEqual(appointment.recommendedFollowUpMonths, 6)
        XCTAssertEqual(appointment.notes, "Trazer óculos antigos")
    }
}
