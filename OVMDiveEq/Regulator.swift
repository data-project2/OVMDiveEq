import Foundation
import SwiftData
import SwiftUI

enum EquipmentKind: String, Codable {
    case cylinder
    case regulator

    var displayName: String {
        switch self {
        case .cylinder:
            "Tank"
        case .regulator:
            "First Stage"
        }
    }
}

struct RegulatorDraft: Equatable {
    var brand = ""
    var type = ""
    var serialNumber = ""
    var serviceDate: Date?
    var nextServiceDate: Date?
    var photoData: Data?

    init() {
    }

    init(regulator: Regulator?) {
        brand = regulator?.brand ?? ""
        type = regulator?.type ?? ""
        serialNumber = regulator?.serialNumber ?? ""
        serviceDate = regulator?.serviceDate
        nextServiceDate = regulator?.nextServiceDate
        photoData = regulator?.photoData
    }

    var normalizedBrand: String {
        brand.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedType: String {
        type.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func apply(to regulator: Regulator) {
        regulator.brand = normalizedBrand
        regulator.type = normalizedType
        regulator.serialNumber = normalizedSerialNumber
        regulator.serviceDate = serviceDate
        regulator.nextServiceDate = nextServiceDate
        regulator.photoData = photoData
        regulator.updatedAt = .now
    }

    func makeRegulator() -> Regulator {
        let regulator = Regulator(brand: normalizedBrand, type: normalizedType)
        apply(to: regulator)
        return regulator
    }

    var normalizedSerialNumber: String {
        serialNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isValid: Bool {
        normalizedBrand.isEmpty == false || normalizedSerialNumber.isEmpty == false
    }
}

@Model
final class Regulator {
    var id: UUID
    var brand: String
    var type: String
    var serialNumber: String
    var serviceDate: Date?
    var nextServiceDate: Date?
    @Attribute(.externalStorage) var photoData: Data?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        brand: String,
        type: String = "",
        serialNumber: String = "",
        serviceDate: Date? = nil,
        nextServiceDate: Date? = nil,
        photoData: Data? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.brand = brand
        self.type = type
        self.serialNumber = serialNumber
        self.serviceDate = serviceDate
        self.nextServiceDate = nextServiceDate
        self.photoData = photoData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var displayName: String {
        [brand.ifEmpty(replacingWith: ""), type.ifEmpty(replacingWith: "First Stage")]
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
            .ifEmpty(replacingWith: "First Stage")
    }

    var inventorySummaryLine: String {
        [type.ifEmpty(replacingWith: "First Stage"), serialDisplayValue]
            .filter { $0.isEmpty == false && $0 != "Not Set" }
            .joined(separator: " • ")
            .ifEmpty(replacingWith: "First Stage")
    }

    var searchableText: String {
        [brand, type, serialNumber]
            .joined(separator: " ")
    }

    var serialDisplayValue: String {
        serialNumber.ifEmpty(replacingWith: "Not Set")
    }
    var overallStatus: MaintenanceStatus {
        RegulatorMaintenanceEvaluator.overallStatus(for: self)
    }

    var draft: RegulatorDraft {
        RegulatorDraft(regulator: self)
    }
}

struct RegulatorMaintenanceSnapshot: Identifiable {
    let regulatorID: UUID
    let regulatorName: String
    let title: String
    let dueDate: Date?
    let status: MaintenanceStatus

    var id: String {
        "\(regulatorID.uuidString)-\(title)"
    }

    var detailText: String {
        CylinderMaintenanceEvaluator.detailText(for: dueDate, label: title)
    }
}

struct EquipmentMaintenanceSnapshot: Identifiable {
    let equipmentID: UUID
    let equipmentName: String
    let equipmentKind: EquipmentKind
    let title: String
    let dueDate: Date?
    let status: MaintenanceStatus

    var id: String {
        "\(equipmentKind.rawValue)-\(equipmentID.uuidString)-\(title)"
    }

    var detailText: String {
        CylinderMaintenanceEvaluator.detailText(for: dueDate, label: title)
    }
}

struct RegulatorMaintenanceEvaluator {
    nonisolated static func overallStatus(
        for regulator: Regulator,
        warningWindowDays: Int = CylinderMaintenanceEvaluator.defaultWarningWindowDays
    ) -> MaintenanceStatus {
        snapshots(for: regulator, warningWindowDays: warningWindowDays)
            .map(\.status)
            .max(by: { $0.priority < $1.priority }) ?? .unknown
    }

    nonisolated static func snapshots(
        for regulator: Regulator,
        warningWindowDays: Int = CylinderMaintenanceEvaluator.defaultWarningWindowDays
    ) -> [RegulatorMaintenanceSnapshot] {
        [
            RegulatorMaintenanceSnapshot(
                regulatorID: regulator.id,
                regulatorName: regulator.displayName,
                title: "Service",
                dueDate: regulator.nextServiceDate,
                status: CylinderMaintenanceEvaluator.status(
                    for: regulator.nextServiceDate,
                    warningWindowDays: warningWindowDays
                )
            )
        ]
    }

    nonisolated static func equipmentSnapshots(
        for regulator: Regulator,
        warningWindowDays: Int = CylinderMaintenanceEvaluator.defaultWarningWindowDays
    ) -> [EquipmentMaintenanceSnapshot] {
        snapshots(for: regulator, warningWindowDays: warningWindowDays).map {
            EquipmentMaintenanceSnapshot(
                equipmentID: $0.regulatorID,
                equipmentName: $0.regulatorName,
                equipmentKind: .regulator,
                title: $0.title,
                dueDate: $0.dueDate,
                status: $0.status
            )
        }
    }
}

struct EquipmentMaintenanceGroups {
    let needsAttention: [EquipmentMaintenanceSnapshot]
    let upcoming: [EquipmentMaintenanceSnapshot]
    let current: [EquipmentMaintenanceSnapshot]
    let unknown: [EquipmentMaintenanceSnapshot]

    init(cylinders: [Cylinder], regulators: [Regulator], warningWindowDays: Int) {
        let cylinderEvents = cylinders.flatMap {
            CylinderMaintenanceEvaluator.equipmentSnapshots(for: $0, warningWindowDays: warningWindowDays)
        }
        let regulatorEvents = regulators.flatMap {
            RegulatorMaintenanceEvaluator.equipmentSnapshots(for: $0, warningWindowDays: warningWindowDays)
        }
        let allEvents = (cylinderEvents + regulatorEvents)
            .sorted(by: EquipmentMaintenanceGroups.sort)

        needsAttention = allEvents.filter { $0.status == .due || $0.status == .approaching }
        upcoming = []
        current = allEvents.filter { $0.status == .ok }
        unknown = allEvents.filter { $0.status == .unknown }
    }

    var totalCount: Int {
        needsAttention.count + upcoming.count + current.count + unknown.count
    }

    nonisolated private static func sort(_ lhs: EquipmentMaintenanceSnapshot, _ rhs: EquipmentMaintenanceSnapshot) -> Bool {
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
            return lhs.equipmentName < rhs.equipmentName
        }
    }
}
