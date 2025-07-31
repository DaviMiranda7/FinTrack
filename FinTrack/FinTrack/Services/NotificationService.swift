import Foundation
import UserNotifications
import FirebaseFirestore

class NotificationService {
    static let shared = NotificationService()
    private init() {}
    
    func sendBalanceNotification(oldBalance: Double, newBalance: Double, transaction: Transaction) {
        let content = UNMutableNotificationContent()
        content.title = "FinTrack - Saldo Atualizado"
        
        let difference = newBalance - oldBalance
        let operation = difference > 0 ? "+" : ""
        
        content.body = """
        \(transaction.type == .income ? "💰" : "💸") \(transaction.category.displayName)
        \(operation)R$ \(String(format: "%.2f", difference))
        Saldo atual: R$ \(String(format: "%.2f", newBalance))
        """
        
        content.sound = .default
        content.badge = 1
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func sendSecurityAlert(message: String) {
        let content = UNMutableNotificationContent()
        content.title = "🔒 FinTrack - Alerta de Segurança"
        content.body = message
        content.sound = .defaultCritical
        content.badge = 1
        
        let request = UNNotificationRequest(
            identifier: "security-\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}
