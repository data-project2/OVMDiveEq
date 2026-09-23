import Foundation
import SwiftData
import SwiftUI

enum CylinderMaterial: String, CaseIterable, Codable, Identifiable {
    case steel
    case aluminum
    case composite

    var id: Self { self }

    var displayName: String {
        switch self {
        case .steel:
            "Steel"
        case .aluminum:
            "Aluminum"
        case .composite:
            "Composite"
        }
    }
}

enum MaintenanceStatus: Int, CaseIterable, Codable {
    case unknown = 0
    case ok = 1
    case approaching = 2
    case due = 3

    nonisolated var priority: Int { rawValue }

    nonisolated var badgeTitle: String {
        switch self {
        case .unknown:
            "Not Set"
        case .ok:
            "Current"
        case .approaching:
            "Approaching"
        case .due:
            "Due"
        }
    }

    nonisolated var symbolName: String {
        switch self {
        case .unknown:
            "questionmark.circle.fill"
        case .ok:
            "checkmark.circle.fill"
        case .approaching:
            "exclamationmark.triangle.fill"
        case .due:
            "exclamationmark.octagon.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .unknown:
            OVMTheme.textTertiary
        case .ok:
            OVMTheme.success
        case .approaching:
            OVMTheme.warning
        case .due:
            OVMTheme.danger
        }
    }

    var backgroundColor: Color {
        switch self {
        case .unknown:
            OVMTheme.card.opacity(0.75)
        case .ok:
            OVMTheme.successBackground
        case .approaching:
            OVMTheme.warningBackground
        case .due:
            OVMTheme.dangerBackground
        }
    }
}

struct CylinderDraft: Equatable {
    var name = ""
    var brand = ""
    var material: CylinderMaterial = .steel
    var volumeLitersText = ""
    var colorName = ""
    var photoData: Data?
    var vipDate: Date?
    var nextVIPDueDate: Date?
    var hydroDate: Date?
    var nextHydroDueDate: Date?
    var notes = ""

    init() {
    }

    init(cylinder: Cylinder?) {
        name = cylinder?.name ?? ""
        brand = cylinder?.brand ?? ""
        material = cylinder?.material ?? .steel
        volumeLitersText = cylinder?.volumeLiters.map { String($0) } ?? ""
        colorName = cylinder?.colorName ?? ""
        photoData = cylinder?.photoData
        vipDate = cylinder?.vipDate
        nextVIPDueDate = cylinder?.nextVIPDueDate
        hydroDate = cylinder?.hydroDate
        nextHydroDueDate = cylinder?.nextHydroDueDate
        notes = cylinder?.notes ?? ""
    }

    var isValid: Bool {
        normalizedName.isEmpty == false
    }

    var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedBrand: String {
        brand.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedColorName: String {
        colorName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedNotes: String {
        notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedVolumeLiters: Double? {
        Double(volumeLitersText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func apply(to cylinder: Cylinder) {
        cylinder.name = normalizedName
        cylinder.brand = normalizedBrand
        cylinder.material = material
        cylinder.volumeLiters = normalizedVolumeLiters
        cylinder.colorName = normalizedColorName
        cylinder.photoData = photoData
        cylinder.vipDate = vipDate
        cylinder.nextVIPDueDate = nextVIPDueDate
        cylinder.hydroDate = hydroDate
        cylinder.nextHydroDueDate = nextHydroDueDate
        cylinder.notes = normalizedNotes
        cylinder.updatedAt = .now
    }

    func makeCylinder() -> Cylinder {
        let cylinder = Cylinder(name: normalizedName)
        apply(to: cylinder)
        return cylinder
    }
}

@Model
final class Cylinder {
    var id: UUID
    var name: String
    var brand: String
    var material: CylinderMaterial
    var volumeLiters: Double?
    var colorName: String
    @Attribute(.externalStorage) var photoData: Data?
    var vipDate: Date?
    var nextVIPDueDate: Date?
    var hydroDate: Date?
    var nextHydroDueDate: Date?
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        brand: String = "",
        material: CylinderMaterial = .steel,
        volumeLiters: Double? = nil,
        colorName: String = "",
        photoData: Data? = nil,
        vipDate: Date? = nil,
        nextVIPDueDate: Date? = nil,
        hydroDate: Date? = nil,
        nextHydroDueDate: Date? = nil,
        notes: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.material = material
        self.volumeLiters = volumeLiters
        self.colorName = colorName
        self.photoData = photoData
        self.vipDate = vipDate
        self.nextVIPDueDate = nextVIPDueDate
        self.hydroDate = hydroDate
        self.nextHydroDueDate = nextHydroDueDate
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var subtitle: String {
        [brand.ifEmpty(replacingWith: ""), volumeDisplayValue, material.displayName, colorDisplayValue]
            .filter { $0.isEmpty == false && $0 != "Not Set" }
            .joined(separator: " • ")
            .ifEmpty(replacingWith: material.displayName)
    }

    var inventorySummaryLine: String {
        [brand.ifEmpty(replacingWith: ""), volumeDisplayValue, material.displayName, colorDisplayValue]
            .filter { $0.isEmpty == false && $0 != "Not Set" }
            .joined(separator: " • ")
            .ifEmpty(replacingWith: material.displayName)
    }

    var searchableText: String {
        [
            name,
            brand,
            material.displayName,
            colorName
        ]
        .joined(separator: " ")
    }

    var overallStatus: MaintenanceStatus {
        CylinderMaintenanceEvaluator.overallStatus(for: self)
    }

    var volumeDisplayValue: String {
        guard let volumeLiters else {
            return "Not Set"
        }
        return "\(volumeLiters.formatted(.number.precision(.fractionLength(0...1)))) L"
    }

    var colorDisplayValue: String {
        colorName.ifEmpty(replacingWith: "Not Set")
    }

    var draft: CylinderDraft {
        CylinderDraft(cylinder: self)
    }
}

struct CylinderMaintenanceSnapshot: Identifiable {
    let cylinderID: UUID
    let cylinderName: String
    let title: String
    let dueDate: Date?
    let status: MaintenanceStatus

    var id: String {
        "\(cylinderID.uuidString)-\(title)"
    }

    var detailText: String {
        CylinderMaintenanceEvaluator.detailText(for: dueDate, label: title)
    }
}

struct CylinderMaintenanceEvaluator {
    nonisolated static let defaultWarningWindowDays = 30

    nonisolated static func status(
        for dueDate: Date?,
        today: Date = .now,
        warningWindowDays: Int = defaultWarningWindowDays,
        calendar: Calendar = .current
    ) -> MaintenanceStatus {
        guard let dueDate else {
            return .unknown
        }

        let startOfToday = calendar.startOfDay(for: today)
        let startOfDueDate = calendar.startOfDay(for: dueDate)

        guard startOfDueDate > startOfToday else {
            return .due
        }

        let approachingDate = calendar.date(byAdding: .day, value: warningWindowDays, to: startOfToday) ?? startOfToday
        if startOfDueDate <= approachingDate {
            return .approaching
        }

        return .ok
    }

    nonisolated static func overallStatus(
        for cylinder: Cylinder,
        warningWindowDays: Int = defaultWarningWindowDays
    ) -> MaintenanceStatus {
        snapshots(for: cylinder, warningWindowDays: warningWindowDays)
            .map(\.status)
            .max(by: { $0.priority < $1.priority }) ?? .unknown
    }

    nonisolated static func snapshots(
        for cylinder: Cylinder,
        warningWindowDays: Int = defaultWarningWindowDays
    ) -> [CylinderMaintenanceSnapshot] {
        [
            CylinderMaintenanceSnapshot(
                cylinderID: cylinder.id,
                cylinderName: cylinder.name,
                title: "VIP",
                dueDate: cylinder.nextVIPDueDate,
                status: status(for: cylinder.nextVIPDueDate, warningWindowDays: warningWindowDays)
            ),
            CylinderMaintenanceSnapshot(
                cylinderID: cylinder.id,
                cylinderName: cylinder.name,
                title: "Hydro",
                dueDate: cylinder.nextHydroDueDate,
                status: status(for: cylinder.nextHydroDueDate, warningWindowDays: warningWindowDays)
            )
        ]
    }

    nonisolated static func equipmentSnapshots(
        for cylinder: Cylinder,
        warningWindowDays: Int = defaultWarningWindowDays
    ) -> [EquipmentMaintenanceSnapshot] {
        snapshots(for: cylinder, warningWindowDays: warningWindowDays).map {
            EquipmentMaintenanceSnapshot(
                equipmentID: $0.cylinderID,
                equipmentName: $0.cylinderName,
                equipmentKind: .cylinder,
                title: $0.title,
                dueDate: $0.dueDate,
                status: $0.status
            )
        }
    }

    nonisolated static func description(
        for dueDate: Date?,
        warningWindowDays: Int = defaultWarningWindowDays
    ) -> String {
        detailText(for: dueDate, label: "", warningWindowDays: warningWindowDays)
            .replacingOccurrences(of: " due ", with: " ")
            .replacingOccurrences(of: " approaching on ", with: " ")
    }

    nonisolated static func detailText(
        for dueDate: Date?,
        label: String,
        warningWindowDays: Int = defaultWarningWindowDays
    ) -> String {
        let prefix = label.isEmpty ? "" : "\(label) "

        switch status(for: dueDate, warningWindowDays: warningWindowDays) {
        case .unknown:
            return "\(prefix)date not set"
        case .due:
            guard let dueDate else {
                return "\(prefix)date not set"
            }
            return "\(prefix)due \(formattedDate(dueDate))"
        case .approaching:
            guard let dueDate else {
                return "\(prefix)date not set"
            }
            return "\(prefix)approaching on \(formattedDate(dueDate))"
        case .ok:
            guard let dueDate else {
                return "\(prefix)date not set"
            }
            return "\(prefix)current until \(formattedDate(dueDate))"
        }
    }

    nonisolated static func formattedDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}

struct CylinderMaintenanceGroups {
    let needsAttention: [CylinderMaintenanceSnapshot]
    let upcoming: [CylinderMaintenanceSnapshot]
    let current: [CylinderMaintenanceSnapshot]
    let unknown: [CylinderMaintenanceSnapshot]

    init(cylinders: [Cylinder], warningWindowDays: Int) {
        let allEvents = cylinders
            .flatMap { CylinderMaintenanceEvaluator.snapshots(for: $0, warningWindowDays: warningWindowDays) }
            .sorted(by: CylinderMaintenanceGroups.sort)

        self.needsAttention = allEvents.filter { $0.status == .due || $0.status == .approaching }
        self.upcoming = []
        self.current = allEvents.filter { $0.status == .ok }
        self.unknown = allEvents.filter { $0.status == .unknown }
    }

    var totalCount: Int {
        needsAttention.count + upcoming.count + current.count + unknown.count
    }

    nonisolated private static func sort(_ lhs: CylinderMaintenanceSnapshot, _ rhs: CylinderMaintenanceSnapshot) -> Bool {
        if lhs.status.priority != rhs.status.priority {
            return lhs.status.priority > rhs.status.priority
        }

        switch (lhs.dueDate, rhs.dueDate) {
        case let (left?, right?):
            return left < right
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            return lhs.cylinderName < rhs.cylinderName
        }
    }
}

extension String {
    func ifEmpty(replacingWith replacement: String) -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? replacement : trimmed
    }
}
