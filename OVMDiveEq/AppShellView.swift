import SwiftData
import SwiftUI

enum AppSettings {
    static let warningWindowDaysKey = "maintenanceWarningWindowDays"
    static let remindersEnabledKey = "localMaintenanceRemindersEnabled"
    static let includesDueDateReminderKey = "localMaintenanceIncludesDueDateReminder"
    static let defaultWarningWindowDays = 30
}

struct AppShellView: View {
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(AppSettings.warningWindowDaysKey) private var warningWindowDays = AppSettings.defaultWarningWindowDays
    @AppStorage(AppSettings.remindersEnabledKey) private var remindersEnabled = false
    @AppStorage(AppSettings.includesDueDateReminderKey) private var includesDueDateReminder = true
    @Query(sort: \Cylinder.updatedAt, order: .reverse) private var cylinders: [Cylinder]
    @Query(sort: \Regulator.updatedAt, order: .reverse) private var regulators: [Regulator]

    private var notificationSettings: NotificationSettings {
        NotificationSettings(
            remindersEnabled: remindersEnabled,
            warningWindowDays: warningWindowDays,
            includesDueDateReminder: includesDueDateReminder
        )
    }

    private var notificationSyncState: [EquipmentNotificationSyncState] {
        let cylinderState = cylinders.map {
            EquipmentNotificationSyncState(
                id: $0.id,
                dueDates: [$0.nextVIPDueDate, $0.nextHydroDueDate],
                updatedAt: $0.updatedAt
            )
        }

        let regulatorState = regulators.map {
            EquipmentNotificationSyncState(
                id: $0.id,
                dueDates: [$0.nextServiceDate],
                updatedAt: $0.updatedAt
            )
        }

        return cylinderState + regulatorState
    }

    private var maintenanceGroups: EquipmentMaintenanceGroups {
        EquipmentMaintenanceGroups(
            cylinders: cylinders,
            regulators: regulators,
            warningWindowDays: warningWindowDays
        )
    }

    private var maintenanceBadge: String? {
        maintenanceGroups.needsAttention.isEmpty ? nil : ""
    }

    var body: some View {
        TabView {
            InventoryRootView(warningWindowDays: warningWindowDays)
                .tabItem {
                    Label("Inventory", systemImage: "shippingbox.fill")
                }

            MaintenanceRootView(warningWindowDays: warningWindowDays)
                .tabItem {
                    Label("Maintenance", systemImage: "wrench.and.screwdriver.fill")
                }
                .badge(maintenanceBadge)

            SettingsRootView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(OVMTheme.accent)
        .background(OVMTheme.background.ignoresSafeArea())
        .task {
            await NotificationService.syncNotifications(
                cylinders: cylinders,
                regulators: regulators,
                settings: notificationSettings
            )
        }
        .onChange(of: notificationSyncState) { _, _ in
            Task {
                await NotificationService.syncNotifications(
                    cylinders: cylinders,
                    regulators: regulators,
                    settings: notificationSettings
                )
            }
        }
        .onChange(of: notificationSettings) { _, newValue in
            Task {
                await NotificationService.syncNotifications(
                    cylinders: cylinders,
                    regulators: regulators,
                    settings: newValue
                )
            }
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else {
                return
            }

            Task {
                await NotificationService.syncNotifications(
                    cylinders: cylinders,
                    regulators: regulators,
                    settings: notificationSettings
                )
            }
        }
    }
}

struct EquipmentNotificationSyncState: Equatable {
    let id: UUID
    let dueDates: [Date?]
    let updatedAt: Date
}

struct InventoryRootView: View {
    let warningWindowDays: Int

    @Query(sort: \Cylinder.updatedAt, order: .reverse) private var cylinders: [Cylinder]
    @Query(sort: \Regulator.updatedAt, order: .reverse) private var regulators: [Regulator]

    @State private var searchText = ""
    @State private var isShowingAddOptions = false
    @State private var presentedEditor: InventoryEditorKind?

    private var filteredCylinders: [Cylinder] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else {
            return cylinders
        }

        return cylinders.filter { cylinder in
            cylinder.searchableText.localizedStandardContains(query)
        }
    }

    private var filteredRegulators: [Regulator] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else {
            return regulators
        }

        return regulators.filter { regulator in
            regulator.searchableText.localizedStandardContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    InventoryScreenContent(
                        cylinders: filteredCylinders,
                        regulators: filteredRegulators,
                        warningWindowDays: warningWindowDays
                    )
                }
                .background(OVMTheme.background.ignoresSafeArea())

                if let presentedEditor {
                    inventoryEditor(for: presentedEditor)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .zIndex(1)
                }
            }
            .navigationTitle("OVM Equipment")
            .searchable(text: $searchText, prompt: "Search equipment")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingAddOptions = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add equipment")
                }
            }
            .confirmationDialog("Add Equipment", isPresented: $isShowingAddOptions) {
                Button("Tank") {
                    presentedEditor = .cylinder
                }

                Button("First Stage") {
                    presentedEditor = .regulator
                }
            }
        }
    }

    @ViewBuilder
    private func inventoryEditor(for kind: InventoryEditorKind) -> some View {
        switch kind {
        case .cylinder:
            CylinderEditorView {
                presentedEditor = nil
            }
        case .regulator:
            RegulatorEditorView {
                presentedEditor = nil
            }
        }
    }
}

struct InventoryScreenContent: View {
    let cylinders: [Cylinder]
    let regulators: [Regulator]
    let warningWindowDays: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            InventoryOverviewCard(
                cylinderCount: cylinders.count,
                regulatorCount: regulators.count
            )
            InventoryCategoryStrip()
            InventoryCylinderSection(
                cylinders: cylinders,
                warningWindowDays: warningWindowDays
            )
            InventoryRegulatorSection(
                regulators: regulators,
                warningWindowDays: warningWindowDays
            )
        }
        .padding(20)
    }
}

struct InventoryOverviewCard: View {
    let cylinderCount: Int
    let regulatorCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your equipment. Your device. Your data.")
                .font(.headline)
                .foregroundStyle(OVMTheme.textPrimary)

            Text(summaryText)
                .font(.subheadline)
                .foregroundStyle(OVMTheme.textSecondary)
        }
        .ovmCardStyle()
    }

    private var summaryText: String {
        let totalCount = cylinderCount + regulatorCount

        if totalCount == 0 {
            return "Start by adding a tank or first stage. Inventory and maintenance stay local on this device."
        } else {
            return "You currently track \(totalCount) item(s): \(cylinderCount) tank(s) and \(regulatorCount) first stage(s)."
        }
    }
}

struct InventoryCategoryStrip: View {
    private let categories: [InventoryCategory] = [
        .init(title: "All", icon: "square.grid.2x2.fill"),
        .init(title: "Tanks", icon: "cylinder.fill"),
        .init(title: "First Stages", icon: "dial.low.fill")
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories) { category in
                    InventoryCategoryPill(category: category)
                }
            }
        }
    }
}

struct InventoryCategoryPill: View {
    let category: InventoryCategory

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: category.icon)
                .imageScale(.small)
            Text(category.title)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(OVMTheme.textPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(OVMTheme.card)
        )
        .overlay(
            Capsule()
                .stroke(OVMTheme.border, lineWidth: 1)
        )
    }
}

struct InventoryCylinderSection: View {
    let cylinders: [Cylinder]
    let warningWindowDays: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tanks")
                .font(.title3.weight(.semibold))
                .foregroundStyle(OVMTheme.textPrimary)

            if cylinders.isEmpty {
                InventoryEmptyStateCard(
                    title: "No tanks yet",
                    message: "Add your first tank to start tracking VIP and hydro dates."
                )
            } else {
                ForEach(cylinders) { cylinder in
                    NavigationLink {
                        CylinderDetailView(
                            cylinder: cylinder,
                            warningWindowDays: warningWindowDays
                        )
                    } label: {
                        CylinderCardView(
                            cylinder: cylinder,
                            warningWindowDays: warningWindowDays
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct InventoryRegulatorSection: View {
    let regulators: [Regulator]
    let warningWindowDays: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("First Stages")
                .font(.title3.weight(.semibold))
                .foregroundStyle(OVMTheme.textPrimary)

            if regulators.isEmpty {
                InventoryEmptyStateCard(
                    title: "No first stages yet",
                    message: "Add a first stage to start tracking service dates."
                )
            } else {
                ForEach(regulators) { regulator in
                    NavigationLink {
                        RegulatorDetailView(
                            regulator: regulator,
                            warningWindowDays: warningWindowDays
                        )
                    } label: {
                        RegulatorCardView(
                            regulator: regulator,
                            warningWindowDays: warningWindowDays
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct CylinderCardView: View {
    let cylinder: Cylinder
    let warningWindowDays: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                HStack(spacing: 4) {
                    Text(cylinder.name)
                        .font(.headline)
                        .foregroundStyle(OVMTheme.textPrimary)

                    Text(cylinder.inventorySummaryLine)
                        .font(.subheadline)
                        .foregroundStyle(OVMTheme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                CylinderStatusBadge(
                    status: CylinderMaintenanceEvaluator.overallStatus(
                        for: cylinder,
                        warningWindowDays: warningWindowDays
                    )
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                CylinderMaintenanceRow(
                    title: "VIP",
                    dueDate: cylinder.nextVIPDueDate,
                    warningWindowDays: warningWindowDays
                )
                CylinderMaintenanceRow(
                    title: "Hydro",
                    dueDate: cylinder.nextHydroDueDate,
                    warningWindowDays: warningWindowDays
                )
            }
        }
        .ovmCardStyle()
    }
}

struct CylinderMaintenanceRow: View {
    let title: LocalizedStringKey
    let dueDate: Date?
    let warningWindowDays: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OVMTheme.textSecondary)

            Spacer(minLength: 0)

            Text(
                CylinderMaintenanceEvaluator.description(
                    for: dueDate,
                    warningWindowDays: warningWindowDays
                )
            )
                .font(.subheadline)
                .foregroundStyle(OVMTheme.textPrimary)
        }
    }
}

struct RegulatorCardView: View {
    let regulator: Regulator
    let warningWindowDays: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(regulator.displayName)
                        .font(.headline)
                        .foregroundStyle(OVMTheme.textPrimary)

                    Text(regulator.inventorySummaryLine)
                        .font(.subheadline)
                        .foregroundStyle(OVMTheme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 0)

                CylinderStatusBadge(
                    status: RegulatorMaintenanceEvaluator.overallStatus(
                        for: regulator,
                        warningWindowDays: warningWindowDays
                    )
                )
            }

            CylinderMaintenanceRow(
                title: "Service",
                dueDate: regulator.nextServiceDate,
                warningWindowDays: warningWindowDays
            )
        }
        .ovmCardStyle()
    }
}

struct InventoryEmptyStateCard: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        EmptyStateCard(
            symbolName: "shippingbox",
            title: title,
            message: message
        )
    }
}

struct CylinderDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let cylinder: Cylinder
    let warningWindowDays: Int

    @State private var isPresentingEditor = false
    @State private var editorDraft = CylinderDraft()
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    CylinderDetailHeader(
                        cylinder: cylinder,
                        warningWindowDays: warningWindowDays
                    )
                    if cylinder.photoData != nil {
                        CylinderPhotoCard(cylinder: cylinder)
                    }
                    CylinderSpecsCard(cylinder: cylinder)
                    CylinderMaintenanceCard(
                        cylinder: cylinder,
                        warningWindowDays: warningWindowDays
                    )

                    if cylinder.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                        CylinderNotesCard(notes: cylinder.notes)
                    }
                }
                .padding(20)
            }
            .background(OVMTheme.background.ignoresSafeArea())

            if isPresentingEditor {
                CylinderEditorView(
                    cylinder: cylinder,
                    draft: $editorDraft,
                    showsActionButtons: false
                ) {
                    isPresentingEditor = false
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(1)
            }
        }
        .navigationTitle(cylinder.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if isPresentingEditor {
                    Button("Save") {
                        saveEdits()
                    }
                    .disabled(editorDraft.isValid == false)
                } else {
                    Button("Edit") {
                        startEditing()
                    }

                    Button(role: .destructive) {
                        isShowingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Delete cylinder")
                }
            }
        }
        .confirmationDialog(
            "Delete this tank?",
            isPresented: $isShowingDeleteConfirmation
        ) {
            Button("Delete Tank", role: .destructive) {
                modelContext.delete(cylinder)
                dismiss()
            }
        } message: {
            Text("This removes the tank and its stored maintenance dates from the device.")
        }
    }

    private func startEditing() {
        editorDraft = cylinder.draft
        isPresentingEditor = true
    }

    private func saveEdits() {
        editorDraft.apply(to: cylinder)
        isPresentingEditor = false
    }
}

struct CylinderDetailHeader: View {
    let cylinder: Cylinder
    let warningWindowDays: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(cylinder.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(OVMTheme.textPrimary)

                    if cylinder.brand.isEmpty == false {
                        Text(cylinder.brand)
                            .font(.subheadline)
                            .foregroundStyle(OVMTheme.textSecondary)
                    }
                }

                Spacer(minLength: 0)

                CylinderStatusBadge(
                    status: CylinderMaintenanceEvaluator.overallStatus(
                        for: cylinder,
                        warningWindowDays: warningWindowDays
                    )
                )
            }

            Text(cylinder.subtitle)
                .font(.subheadline)
                .foregroundStyle(OVMTheme.textSecondary)
        }
        .ovmCardStyle()
    }
}

struct CylinderSpecsCard: View {
    let cylinder: Cylinder

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tank Details")
                .font(.headline)
                .foregroundStyle(OVMTheme.textPrimary)

            CylinderDetailValueRow(label: "Brand", value: cylinder.brand.ifEmpty(replacingWith: "Not Set"))
            CylinderDetailValueRow(label: "Material", value: cylinder.material.displayName)
            CylinderDetailValueRow(label: "Volume", value: cylinder.volumeDisplayValue)
            CylinderDetailValueRow(label: "Color", value: cylinder.colorDisplayValue)
        }
        .ovmCardStyle()
    }
}

struct CylinderPhotoCard: View {
    let cylinder: Cylinder

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Photo")
                .font(.headline)
                .foregroundStyle(OVMTheme.textPrimary)

            if let image = photoImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
        .ovmCardStyle()
    }

    private var photoImage: UIImage? {
        guard let photoData = cylinder.photoData else {
            return nil
        }

        return UIImage(data: photoData)
    }
}

struct CylinderMaintenanceCard: View {
    let cylinder: Cylinder
    let warningWindowDays: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Maintenance")
                .font(.headline)
                .foregroundStyle(OVMTheme.textPrimary)

            ForEach(
                CylinderMaintenanceEvaluator.snapshots(
                    for: cylinder,
                    warningWindowDays: warningWindowDays
                )
            ) { snapshot in
                CylinderMaintenanceDetailRow(
                    snapshot: snapshot,
                    warningWindowDays: warningWindowDays
                )
            }
        }
        .ovmCardStyle()
    }
}

struct CylinderMaintenanceDetailRow: View {
    let snapshot: CylinderMaintenanceSnapshot
    let warningWindowDays: Int

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: snapshot.status.symbolName)
                .foregroundStyle(snapshot.status.tintColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(OVMTheme.textPrimary)

                Text(
                    CylinderMaintenanceEvaluator.detailText(
                        for: snapshot.dueDate,
                        label: snapshot.title,
                        warningWindowDays: warningWindowDays
                    )
                )
                    .font(.subheadline)
                    .foregroundStyle(OVMTheme.textSecondary)
            }

            Spacer(minLength: 0)

            CylinderStatusBadge(status: snapshot.status)
        }
    }
}

struct CylinderNotesCard: View {
    let notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.headline)
                .foregroundStyle(OVMTheme.textPrimary)

            Text(notes)
                .font(.subheadline)
                .foregroundStyle(OVMTheme.textSecondary)
        }
        .ovmCardStyle()
    }
}

struct RegulatorDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let regulator: Regulator
    let warningWindowDays: Int

    @State private var isPresentingEditor = false
    @State private var editorDraft = RegulatorDraft()
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    RegulatorDetailHeader(
                        regulator: regulator,
                        warningWindowDays: warningWindowDays
                    )
                    if regulator.photoData != nil {
                        RegulatorPhotoCard(regulator: regulator)
                    }
                    RegulatorSpecsCard(regulator: regulator)
                    RegulatorMaintenanceCard(
                        regulator: regulator,
                        warningWindowDays: warningWindowDays
                    )
                }
                .padding(20)
            }
            .background(OVMTheme.background.ignoresSafeArea())

            if isPresentingEditor {
                RegulatorEditorView(
                    regulator: regulator,
                    draft: $editorDraft,
                    showsActionButtons: false
                ) {
                    isPresentingEditor = false
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(1)
            }
        }
        .navigationTitle(regulator.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if isPresentingEditor {
                    Button("Save") {
                        saveEdits()
                    }
                    .disabled(editorDraft.isValid == false)
                } else {
                    Button("Edit") {
                        startEditing()
                    }

                    Button(role: .destructive) {
                        isShowingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                        .accessibilityLabel("Delete first stage")
                }
            }
        }
        .confirmationDialog(
            "Delete this first stage?",
            isPresented: $isShowingDeleteConfirmation
        ) {
            Button("Delete First Stage", role: .destructive) {
                modelContext.delete(regulator)
                dismiss()
            }
        } message: {
            Text("This removes the first stage and its stored service dates from the device.")
        }
    }

    private func startEditing() {
        editorDraft = regulator.draft
        isPresentingEditor = true
    }

    private func saveEdits() {
        editorDraft.apply(to: regulator)
        isPresentingEditor = false
    }
}

struct RegulatorDetailHeader: View {
    let regulator: Regulator
    let warningWindowDays: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(regulator.displayName)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(OVMTheme.textPrimary)

                    if regulator.serialNumber.isEmpty == false {
                        Text("Serial \(regulator.serialNumber)")
                            .font(.subheadline)
                            .foregroundStyle(OVMTheme.textSecondary)
                    }
                }

                Spacer(minLength: 0)

                CylinderStatusBadge(
                    status: RegulatorMaintenanceEvaluator.overallStatus(
                        for: regulator,
                        warningWindowDays: warningWindowDays
                    )
                )
            }

            Text(regulator.inventorySummaryLine)
                .font(.subheadline)
                .foregroundStyle(OVMTheme.textSecondary)
        }
        .ovmCardStyle()
    }
}

struct RegulatorSpecsCard: View {
    let regulator: Regulator

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("First Stage Details")
                .font(.headline)
                .foregroundStyle(OVMTheme.textPrimary)

            CylinderDetailValueRow(label: "Brand", value: regulator.brand.ifEmpty(replacingWith: "Not Set"))
            CylinderDetailValueRow(label: "Type", value: regulator.type.ifEmpty(replacingWith: "Not Set"))
            CylinderDetailValueRow(label: "Serial Number", value: regulator.serialDisplayValue)
        }
        .ovmCardStyle()
    }
}

struct RegulatorPhotoCard: View {
    let regulator: Regulator

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Photo")
                .font(.headline)
                .foregroundStyle(OVMTheme.textPrimary)

            if let image = photoImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
        .ovmCardStyle()
    }

    private var photoImage: UIImage? {
        guard let photoData = regulator.photoData else {
            return nil
        }

        return UIImage(data: photoData)
    }
}

struct RegulatorMaintenanceCard: View {
    let regulator: Regulator
    let warningWindowDays: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Maintenance")
                .font(.headline)
                .foregroundStyle(OVMTheme.textPrimary)

            ForEach(
                RegulatorMaintenanceEvaluator.snapshots(
                    for: regulator,
                    warningWindowDays: warningWindowDays
                )
            ) { snapshot in
                RegulatorMaintenanceDetailRow(
                    snapshot: snapshot,
                    warningWindowDays: warningWindowDays
                )
            }
        }
        .ovmCardStyle()
    }
}

struct RegulatorMaintenanceDetailRow: View {
    let snapshot: RegulatorMaintenanceSnapshot
    let warningWindowDays: Int

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: snapshot.status.symbolName)
                .foregroundStyle(snapshot.status.tintColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(OVMTheme.textPrimary)

                Text(
                    CylinderMaintenanceEvaluator.detailText(
                        for: snapshot.dueDate,
                        label: snapshot.title,
                        warningWindowDays: warningWindowDays
                    )
                )
                .font(.subheadline)
                .foregroundStyle(OVMTheme.textSecondary)
            }

            Spacer(minLength: 0)

            CylinderStatusBadge(status: snapshot.status)
        }
    }
}

struct CylinderDetailValueRow: View {
    let label: LocalizedStringKey
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OVMTheme.textSecondary)

            Spacer(minLength: 12)

            Text(value)
                .font(.subheadline)
                .foregroundStyle(OVMTheme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct CylinderStatusBadge: View {
    let status: MaintenanceStatus

    var body: some View {
        Label(status.badgeTitle, systemImage: status.symbolName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(status.tintColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(status.backgroundColor)
            )
    }
}

struct MaintenanceRootView: View {
    let warningWindowDays: Int

    @Query(sort: \Cylinder.updatedAt, order: .reverse) private var cylinders: [Cylinder]
    @Query(sort: \Regulator.updatedAt, order: .reverse) private var regulators: [Regulator]

    private var groupedEvents: EquipmentMaintenanceGroups {
        EquipmentMaintenanceGroups(
            cylinders: cylinders,
            regulators: regulators,
            warningWindowDays: warningWindowDays
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                MaintenanceScreenContent(
                    groups: groupedEvents,
                    warningWindowDays: warningWindowDays
                )
            }
            .background(OVMTheme.background.ignoresSafeArea())
            .navigationTitle("Maintenance")
        }
    }
}

struct MaintenanceScreenContent: View {
    let groups: EquipmentMaintenanceGroups
    let warningWindowDays: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            MaintenanceSummaryCard(
                groups: groups,
                warningWindowDays: warningWindowDays
            )
            MaintenanceEventSection(title: "Needs Attention", events: groups.needsAttention)
            MaintenanceEventSection(title: "Upcoming", events: groups.upcoming)
            MaintenanceEventSection(title: "Current", events: groups.current)
            MaintenanceEventSection(title: "Date Not Set", events: groups.unknown)
        }
        .padding(20)
    }
}

struct MaintenanceSummaryCard: View {
    let groups: EquipmentMaintenanceGroups
    let warningWindowDays: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What needs attention before the next dive?")
                .font(.headline)
                .foregroundStyle(OVMTheme.textPrimary)

            Text(summaryText)
                .font(.subheadline)
                .foregroundStyle(OVMTheme.textSecondary)

            Text("Current warning window: \(warningWindowDays) day(s) before a due date.")
                .font(.caption)
                .foregroundStyle(OVMTheme.textTertiary)
        }
        .ovmCardStyle()
    }

    private var summaryText: LocalizedStringKey {
        if groups.totalCount == 0 {
            "Add a tank or first stage to see maintenance reminders here."
        } else if groups.needsAttention.isEmpty == false {
            "You have \(groups.needsAttention.count) maintenance item(s) that need attention."
        } else if groups.upcoming.isEmpty == false {
            "No equipment maintenance is due today. Upcoming reminders are listed below."
        } else {
            "All tracked equipment maintenance dates are currently outside the warning window."
        }
    }
}

struct MaintenanceEventSection: View {
    let title: LocalizedStringKey
    let events: [EquipmentMaintenanceSnapshot]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(OVMTheme.textPrimary)

            if events.isEmpty {
                EmptyStateCard(
                    symbolName: "calendar.badge.exclamationmark",
                    title: title,
                    message: emptyStateMessage
                )
            } else {
                ForEach(events) { event in
                    MaintenanceEventRow(event: event)
                }
            }
        }
    }

    private var emptyStateMessage: LocalizedStringKey {
        switch title {
        case "Needs Attention":
            "No VIP, hydro, or service dates are currently due or approaching."
        case "Upcoming":
            "Future equipment maintenance reminders will appear here."
        case "Current":
            "Current equipment maintenance dates will appear here."
        default:
            "Equipment without maintenance due dates will appear here."
        }
    }
}

struct MaintenanceEventRow: View {
    let event: EquipmentMaintenanceSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.equipmentName)
                        .font(.headline)
                        .foregroundStyle(OVMTheme.textPrimary)

                    Text("\(event.equipmentKind.displayName) • \(event.title)")
                        .font(.subheadline)
                        .foregroundStyle(OVMTheme.textSecondary)
                }

                Spacer(minLength: 0)

                CylinderStatusBadge(status: event.status)
            }

            Text(event.detailText)
                .font(.subheadline)
                .foregroundStyle(OVMTheme.textSecondary)
        }
        .ovmCardStyle()
    }
}

struct SettingsRootView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                SettingsScreenContent()
            }
            .background(OVMTheme.background.ignoresSafeArea())
            .navigationTitle("Settings")
        }
    }
}

struct SettingsScreenContent: View {
    @AppStorage(AppSettings.warningWindowDaysKey) private var warningWindowDays = AppSettings.defaultWarningWindowDays
    @AppStorage(AppSettings.remindersEnabledKey) private var remindersEnabled = false
    @AppStorage(AppSettings.includesDueDateReminderKey) private var includesDueDateReminder = true

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsSectionCard(
                title: "Privacy First",
                items: [
                    "No account or login",
                    "No cloud sync or backend",
                    "No analytics or tracking SDKs"
                ]
            )
            SettingsSectionCard(
                title: "Equipment Support",
                items: [
                    "Local-only tank records",
                    "Local-only first stage records",
                    "VIP, hydro, and service maintenance status",
                    "Popup equipment entry and editing"
                ]
            )
            MaintenanceWarningSettingsCard(
                warningWindowDays: $warningWindowDays,
                remindersEnabled: $remindersEnabled,
                includesDueDateReminder: $includesDueDateReminder
            )
            SettingsSectionCard(
                title: "Coming Next",
                items: [
                    "Reminder preferences",
                    "Notification permissions",
                    "Additional equipment types"
                ]
            )
        }
        .padding(20)
    }
}

struct SettingsSectionCard: View {
    let title: LocalizedStringKey
    let items: [LocalizedStringKey]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
                .foregroundStyle(OVMTheme.textPrimary)

            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                SettingsListRow(text: item)
            }
        }
        .ovmCardStyle()
    }
}

struct SettingsListRow: View {
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(OVMTheme.accent)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(OVMTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct MaintenanceWarningSettingsCard: View {
    @Binding var warningWindowDays: Int
    @Binding var remindersEnabled: Bool
    @Binding var includesDueDateReminder: Bool

    @State private var isRequestingPermission = false
    @State private var isShowingPermissionAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Maintenance Warning")
                .font(.headline)
                .foregroundStyle(OVMTheme.textPrimary)

            Text("Choose how many days before a due date the app should treat VIP, hydro, or service as approaching.")
                .font(.subheadline)
                .foregroundStyle(OVMTheme.textSecondary)

            Toggle(isOn: remindersEnabledBinding) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable Local Reminders")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(OVMTheme.textPrimary)

                    Text("Request notification permission only when you choose to enable reminders.")
                        .font(.caption)
                        .foregroundStyle(OVMTheme.textTertiary)
                }
            }
            .disabled(isRequestingPermission)

            Stepper(value: $warningWindowDays, in: 0...365) {
                HStack {
                    Text("Warn Before Due Date")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(OVMTheme.textPrimary)

                    Spacer(minLength: 12)

                    Text("\(warningWindowDays) day(s)")
                        .font(.subheadline)
                        .foregroundStyle(OVMTheme.accent)
                }
            }
            .disabled(remindersEnabled == false)

            Toggle(isOn: $includesDueDateReminder) {
                Text("Also Remind On Due Date")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(OVMTheme.textPrimary)
            }
            .disabled(remindersEnabled == false)

            Text("When one or more equipment items are due or inside that window, the Maintenance tab shows a red-dot badge.")
                .font(.caption)
                .foregroundStyle(OVMTheme.textTertiary)
        }
        .ovmCardStyle()
        .alert("Notifications Not Enabled", isPresented: $isShowingPermissionAlert) {
            Button("OK", role: .cancel) {
            }
        } message: {
            Text("Notification permission was not granted, so local reminders remain off.")
        }
    }

    private var remindersEnabledBinding: Binding<Bool> {
        Binding(
            get: { remindersEnabled },
            set: { newValue in
                guard newValue else {
                    remindersEnabled = false
                    return
                }

                Task {
                    await requestNotificationPermission()
                }
            }
        )
    }

    @MainActor
    private func requestNotificationPermission() async {
        guard isRequestingPermission == false else {
            return
        }

        isRequestingPermission = true
        let granted = await NotificationService.requestAuthorization()
        isRequestingPermission = false

        remindersEnabled = granted
        if granted == false {
            isShowingPermissionAlert = true
        }
    }
}

struct EmptyStateCard: View {
    let symbolName: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: symbolName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(OVMTheme.accent)

            Text(title)
                .font(.headline)
                .foregroundStyle(OVMTheme.textPrimary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(OVMTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ovmCardStyle()
    }
}

struct InventoryCategory: Identifiable {
    let id = UUID()
    let title: LocalizedStringKey
    let icon: String
}

enum InventoryEditorKind {
    case cylinder
    case regulator
}

#Preview {
    AppShellView()
        .modelContainer(for: [Cylinder.self, Regulator.self], inMemory: true)
}
