import Foundation

enum ExistingInstanceMessenger {
    static let showWindowNotification = Notification.Name("com.morphy.showMainWindow")

    static func requestShowMainWindow() {
        DistributedNotificationCenter.default().postNotificationName(
            showWindowNotification,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }
}
