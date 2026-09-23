import SwiftData
import SwiftUI

struct AppShellView: View {
    var body: some View {
        TabView {
            InventoryRootView()
                .tabItem {
                    Label("Inventory", systemImage: "shippingbox.fill")
                }

            MaintenanceRootView()
                .tabItem {
                    Label("Maintenance", systemImage: "wrench.and.screwdriver.fill")
                }

            SettingsRootView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(OVMTheme.accent)
        .background(OVMTheme.background.ignoresSafeArea())
    }
}

struct InventoryRootView: View {
    @Query(sort: \Cylinder.updatedAt, order: .reverse) private var cylinders: [Cylinder]

    @State private var searchText = ""
    @State private var isPresentingAddSheet = false

    private var filteredCylinders: [Cylinder] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else {
            return cylinders
        }

        return cylinders.filter { cylinder in
            cylinder.searchableText.localizedStandardContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    InventoryScreenContent(cylinders: filteredCylinders)
                }
                .background(OVMTheme.background.ignoresSafeArea())

                if isPresentingAddSheet {
                    CylinderEditorView {
                        isPresentingAddSheet = false
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(1)
                }
            }
            .navigationTitle("OVM Equipment")
            .searchable(text: $searchText, prompt: "Search tanks")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add tank")
                }
            }
        }
    }
}

struct InventoryScreenContent: View {
    let cylinders: [Cylinder]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            InventoryOverviewCard(cylinderCount: cylinders.count)
            InventoryCategoryStrip()
            InventoryCylinderSection(cylinders: cylinders)
        }
        .padding(20)
    }
}

struct InventoryOverviewCard: View {
    let cylinderCount: Int

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

    private var summaryText: LocalizedStringKey {
        if cylinderCount == 0 {
            "Start by adding a tank. Inventory and maintenance stay local on this device."
        } else {
            "You currently track \(cylinderCount) tank(s) locally on this device."
        }
    }
}

struct InventoryCategoryStrip: View {
    private let categories: [InventoryCategory] = [
        .init(title: "All", icon: "square.grid.2x2.fill"),
        .init(title: "Tanks", icon: "cylinder.fill")
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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tanks")
                .font(.title3.weight(.semibold))
                .foregroundStyle(OVMTheme.textPrimary)

            if cylinders.isEmpty {
                InventoryEmptyStateCard()
            } else {
                ForEach(cylinders) { cylinder in
                    NavigationLink {
                        CylinderDetailView(cylinder: cylinder)
                    } label: {
                        CylinderCardView(cylinder: cylinder)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct CylinderCardView: View {
    let cylinder: Cylinder

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(cylinder.name)
                        .font(.headline)
                        .foregroundStyle(OVMTheme.textPrimary)

                    Text(cylinder.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(OVMTheme.textSecondary)
                }

                Spacer(minLength: 0)

                CylinderStatusBadge(status: cylinder.overallStatus)
            }

            VStack(alignment: .leading, spacing: 10) {
                CylinderMaintenanceRow(title: "VIP", dueDate: cylinder.nextVIPDueDate)
                CylinderMaintenanceRow(title: "Hydro", dueDate: cylinder.nextHydroDueDate)
            }
        }
        .ovmCardStyle()
    }
}

struct CylinderMaintenanceRow: View {
    let title: LocalizedStringKey
    let dueDate: Date?

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OVMTheme.textSecondary)

            Spacer(minLength: 0)

            Text(CylinderMaintenanceEvaluator.description(for: dueDate))
                .font(.subheadline)
                .foregroundStyle(OVMTheme.textPrimary)
        }
    }
}

struct InventoryEmptyStateCard: View {
    var body: some View {
        EmptyStateCard(
            symbolName: "shippingbox",
            title: "No tanks yet",
            message: "Add your first tank to start tracking VIP and hydro dates."
        )
    }
}

struct CylinderDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let cylinder: Cylinder

    @State private var isPresentingEditor = false
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    CylinderDetailHeader(cylinder: cylinder)
                    CylinderSpecsCard(cylinder: cylinder)
                    CylinderMaintenanceCard(cylinder: cylinder)

                    if cylinder.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                        CylinderNotesCard(notes: cylinder.notes)
                    }
                }
                .padding(20)
            }
            .background(OVMTheme.background.ignoresSafeArea())

            if isPresentingEditor {
                CylinderEditorView(cylinder: cylinder) {
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
                Button("Edit") {
                    isPresentingEditor = true
                }

                Button(role: .destructive) {
                    isShowingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete cylinder")
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
}

struct CylinderDetailHeader: View {
    let cylinder: Cylinder

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

                CylinderStatusBadge(status: cylinder.overallStatus)
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

struct CylinderMaintenanceCard: View {
    let cylinder: Cylinder

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Maintenance")
                .font(.headline)
                .foregroundStyle(OVMTheme.textPrimary)

            ForEach(CylinderMaintenanceEvaluator.snapshots(for: cylinder)) { snapshot in
                CylinderMaintenanceDetailRow(snapshot: snapshot)
            }
        }
        .ovmCardStyle()
    }
}

struct CylinderMaintenanceDetailRow: View {
    let snapshot: CylinderMaintenanceSnapshot

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: snapshot.status.symbolName)
                .foregroundStyle(snapshot.status.tintColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(OVMTheme.textPrimary)

                Text(snapshot.detailText)
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
    @Query(sort: \Cylinder.updatedAt, order: .reverse) private var cylinders: [Cylinder]

    private var groupedEvents: CylinderMaintenanceGroups {
        CylinderMaintenanceGroups(cylinders: cylinders)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                MaintenanceScreenContent(groups: groupedEvents)
            }
            .background(OVMTheme.background.ignoresSafeArea())
            .navigationTitle("Maintenance")
        }
    }
}

struct MaintenanceScreenContent: View {
    let groups: CylinderMaintenanceGroups

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            MaintenanceSummaryCard(groups: groups)
            MaintenanceEventSection(title: "Needs Attention", events: groups.needsAttention)
            MaintenanceEventSection(title: "Upcoming", events: groups.upcoming)
            MaintenanceEventSection(title: "Current", events: groups.current)
            MaintenanceEventSection(title: "Date Not Set", events: groups.unknown)
        }
        .padding(20)
    }
}

struct MaintenanceSummaryCard: View {
    let groups: CylinderMaintenanceGroups

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What needs attention before the next dive?")
                .font(.headline)
                .foregroundStyle(OVMTheme.textPrimary)

            Text(summaryText)
                .font(.subheadline)
                .foregroundStyle(OVMTheme.textSecondary)
        }
        .ovmCardStyle()
    }

    private var summaryText: LocalizedStringKey {
        if groups.totalCount == 0 {
            "Add a tank to see VIP and hydro reminders here."
        } else if groups.needsAttention.isEmpty == false {
            "You have \(groups.needsAttention.count) maintenance item(s) that need attention."
        } else if groups.upcoming.isEmpty == false {
            "No tank maintenance is due today. Upcoming reminders are listed below."
        } else {
            "All tracked tank maintenance dates are currently outside the warning window."
        }
    }
}

struct MaintenanceEventSection: View {
    let title: LocalizedStringKey
    let events: [CylinderMaintenanceSnapshot]

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
            "No VIP or hydro dates are currently due or approaching."
        case "Upcoming":
            "Future tank maintenance reminders will appear here."
        case "Current":
            "Current tank maintenance dates will appear here."
        default:
            "Tanks without VIP or hydro due dates will appear here."
        }
    }
}

struct MaintenanceEventRow: View {
    let event: CylinderMaintenanceSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.cylinderName)
                        .font(.headline)
                        .foregroundStyle(OVMTheme.textPrimary)

                    Text(event.title)
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
                title: "Tank Support",
                items: [
                    "Local-only tank records",
                    "VIP and hydro maintenance status",
                    "Popup tank entry and editing"
                ]
            )
            SettingsSectionCard(
                title: "Coming Next",
                items: [
                    "Reminder preferences",
                    "Notification permissions",
                    "Regulator support"
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

#Preview {
    AppShellView()
        .modelContainer(for: Cylinder.self, inMemory: true)
}
