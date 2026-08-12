import SwiftUI
import StateObservationKit

@main
struct TimerExampleApp: App {
    var body: some Scene {
        WindowGroup {
            TimerExampleView(duration: 25)
        }
    }
}
