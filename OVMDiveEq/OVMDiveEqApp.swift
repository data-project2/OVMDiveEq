import SwiftData
import SwiftUI

@main struct OVMDiveEqApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Cylinder.self, Regulator.self])
    }
}
