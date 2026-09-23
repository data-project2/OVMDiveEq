import Foundation
import UserNotifications

struct NotificationSettings: Equatable {
    let remindersEnabled: Bool
    let warningWindowDays: Int
    let includesDueDateReminder: Bool
}

enum NotificationService {
    private static let identifierPrefix = "equipment-maintenance"
    private static let reminderHour = 9

    static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    static func syncNotifications(
        cylinders: [Cylinder],
        regulators: [Regulator],
        settings: NotificationSettings
    ) async {
        let identifiersToRemove = await managedPendingIdentifiers()
        if identifiersToRemove.isEmpty == false {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        }

        guard settings.remindersEnabled else {
            return
        }

        for cylinder in cylinders {
            await scheduleNotifications(for: cylinder, settings: settings)
        }

        for regulator in regulators {
            await scheduleNotifications(for: regulator, settings: settings)
        }
    }

    private static func scheduleNotifications(
        for cylinder: Cylinder,
        settings: NotificationSettings
    ) async {
        let events = CylinderMaintenanceEvaluator.snapshots(
            for: cylinder,
            warningWindowDays: settings.warningWindowDays
        )

        for event in events {
            guard let dueDate = event.dueDate else {
                continue
            }

            if settings.warningWindowDays > 0,
               let reminderDate = reminderDate(for: dueDate, daysBefore: settings.warningWindowDays) {
                await addRequest(
                    identifier: identifier(
                        for: cylinder.id,
                        kind: .cylinder,
                        event: event.title,
                        suffix: "warning-\(settings.warningWindowDays)"
                    ),
                    title: notificationTitle(for: event.title, state: .approaching),
                    body: "\(cylinder.name) is due on \(CylinderMaintenanceEvaluator.formattedDate(dueDate)).",
                    fireDate: reminderDate
                )
            }

            if settings.includesDueDateReminder,
               let dueReminderDate = reminderDate(for: dueDate, daysBefore: 0) {
                await addRequest(
                    identifier: identifier(
                        for: cylinder.id,
                        kind: .cylinder,
                        event: event.title,
                        suffix: "due"
                    ),
                    title: notificationTitle(for: event.title, state: .due),
                    body: "\(cylinder.name) is due today.",
                    fireDate: dueReminderDate
                )
            }
        }
    }

    private static func scheduleNotifications(
        for regulator: Regulator,
        settings: NotificationSettings
    ) async {
        let events = RegulatorMaintenanceEvaluator.snapshots(
            for: regulator,
            warningWindowDays: settings.warningWindowDays
        )

        for event in events {
            guard let dueDate = event.dueDate else {
                continue
            }

            if settings.warningWindowDays > 0,
               let reminderDate = reminderDate(for: dueDate, daysBefore: settings.warningWindowDays) {
                await addRequest(
                    identifier: identifier(
                        for: regulator.id,
                        kind: .regulator,
                        event: event.title,
                        suffix: "warning-\(settings.warningWindowDays)"
                    ),
                    title: notificationTitle(for: event.title, state: .approaching),
                    body: "\(regulator.displayName) is due on \(CylinderMaintenanceEvaluator.formattedDate(dueDate)).",
                    fireDate: reminderDate
                )
            }

            if settings.includesDueDateReminder,
               let dueReminderDate = reminderDate(for: dueDate, daysBefore: 0) {
                await addRequest(
                    identifier: identifier(
                        for: regulator.id,
                        kind: .regulator,
                        event: event.title,
                        suffix: "due"
                    ),
                    title: notificationTitle(for: event.title, state: .due),
                    body: "\(regulator.displayName) is due today.",
                    fireDate: dueReminderDate
                )
            }
        }
    }

    private static func notificationTitle(for event: String, state: MaintenanceStatus) -> String {
        switch state {
        case .approaching:
            return "\(event) due soon"
        case .due:
            return "\(event) due today"
        default:
            return "\(event) reminder"
        }
    }

    private static func reminderDate(for dueDate: Date, daysBefore: Int, calendar: Calendar = .current) -> Date? {
        let startOfDueDate = calendar.startOfDay(for: dueDate)
        guard let candidateDay = calendar.date(byAdding: .day, value: -daysBefore, to: startOfDueDate),
              let fireDate = calendar.date(
                bySettingHour: reminderHour,
                minute: 0,
                second: 0,
                of: candidateDay
              ) else {
            return nil
        }

        return fireDate > .now ? fireDate : nil
    }

    private static func addRequest(
        identifier: String,
        title: String,
        body: String,
        fireDate: Date
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let triggerComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().add(request) { _ in
                continuation.resume()
            }
        }
    }

    private static func managedPendingIdentifiers() async -> [String] {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                continuation.resume(
                    returning: requests
                        .map(\.identifier)
                        .filter { $0.hasPrefix(identifierPrefix) }
                )
            }
        }
    }

    private static func identifier(for itemID: UUID, kind: EquipmentKind, event: String, suffix: String) -> String {
        "\(identifierPrefix).\(kind.rawValue).\(itemID.uuidString).\(event.lowercased()).\(suffix)"
    }
}
