import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var leaderLock: MonitoringLeaderLock?

    func applicationWillFinishLaunching(_ notification: Notification) {
        do {
            leaderLock = try MonitoringLeaderLock.acquire()
        } catch {
            ExistingInstanceMessenger.requestShowMainWindow()
            NSApp.terminate(nil)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
