import Foundation
import ServiceManagement

@MainActor
class LaunchAtLoginService: ObservableObject {
    @Published var isEnabled: Bool

    init() {
        self.isEnabled = SMAppService.mainApp.status == .enabled
    }

    func toggle() {
        do {
            if isEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            Log.error("Failed to toggle Launch at Login", error: error, category: Log.general)
        }
        self.isEnabled = SMAppService.mainApp.status == .enabled
    }
}
