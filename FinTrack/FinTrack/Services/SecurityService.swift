import Foundation
import FirebaseAuth
import FirebaseFirestore
import CoreLocation
import LocalAuthentication
import DeviceCheck

class SecurityService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = SecurityService()
    private let locationManager = CLLocationManager()
    private let db = Firestore.firestore()
    private var previousLocations: [CLLocation] = []
    private let maxSpeedThreshold: CLLocationSpeed = 300 // 300 m/s (≈ 1080 km/h) - unrealistic speed
    private let minDistanceThreshold: CLLocationDistance = 1000 // 1km minimum distance to check
    private let timeWindow: TimeInterval = 10 * 60 // 10 minutes in seconds
    
    @Published var isDeviceSecure = true
    @Published var locationAuthorized = false
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    // MARK: - Device Security Check
    func checkDeviceSecurity() async -> Bool {
        let context = LAContext()
        var error: NSError?
        
        // Verificar se device tem biometria
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            await sendSecurityAlert("Dispositivo sem biometria detectado")
            return false
        }
        
        // Verificar se device está com jailbreak
        if isJailbroken() {
            await sendSecurityAlert("Dispositivo com jailbreak detectado")
            return false
        }
        
        // Verificar integridade do device
        if #available(iOS 11.0, *) {
            let deviceCheck = DCDevice.current
            if deviceCheck.isSupported {
                // Implementar verificação adicional se necessário
            }
        }
        
        return true
    }
    
    private func isJailbroken() -> Bool {
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt"
        ]
        
        for path in jailbreakPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Location Tracking
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startLocationTracking() {
        guard locationAuthorized else { return }
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last,
              let userId = Auth.auth().currentUser?.uid else { return }
        
        // Salvar localização no Firestore
        let locationData: [String: Any] = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "timestamp": Date(),
            "accuracy": location.horizontalAccuracy
        ]
        
        db.collection("users").document(userId).collection("locations").addDocument(data: locationData)
        
        // Verificar localização suspeita (opcional)
        checkSuspiciousLocation(location)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        locationAuthorized = status == .authorizedWhenInUse || status == .authorizedAlways
    }


    private func checkSuspiciousLocation(_ location: CLLocation) -> Bool {
        // Filter out invalid locations
        guard location.horizontalAccuracy >= 0 else { return false }
        
        // Add current location to history
        previousLocations.append(location)
        
        // Keep only locations within our time window
        previousLocations = previousLocations.filter {
            abs($0.timestamp.timeIntervalSinceNow) <= timeWindow
        }
        
        // Need at least 2 locations to compare
        guard previousLocations.count >= 2 else { return false }
        
        let currentLocation = previousLocations.last!
        let previousLocation = previousLocations[previousLocations.count - 2]
        
        // Calculate distance and time difference
        let distance = currentLocation.distance(from: previousLocation)
        let timeInterval = currentLocation.timestamp.timeIntervalSince(previousLocation.timestamp)
        
        // Check for impossible speeds
        if timeInterval > 0 {
            let speed = distance / timeInterval
            
            if speed > maxSpeedThreshold {
                Task {
                    await sendSecurityAlert("Velocidade suspeita detectada: \(Int(speed * 3.6)) km/h. Possível uso não autorizado.")
                }
                return true
            }
        }
        
        // Check for impossible location jumps (teleportation)
        if distance > minDistanceThreshold && timeInterval < 60 {
            Task {
                await sendSecurityAlert("Mudança de localização suspeita: \(Int(distance))m em \(Int(timeInterval))s. Possível clonagem de dispositivo.")
            }
            return true
        }
        
        // Additional check: altitude changes (if relevant)
        if abs(currentLocation.altitude - previousLocation.altitude) > 1000 && timeInterval < 60 {
            Task {
                await sendSecurityAlert("Mudança de altitude suspeita detectada. Verificação de segurança necessária.")
            }
            return true
        }
        
        return false
    }

    
    // MARK: - Transaction Security
    func validateTransaction(_ transaction: Transaction) async -> Bool {
        guard let userId = Auth.auth().currentUser?.uid else { return false }
        
        // Verificar padrões suspeitos
        let recentTransactions = try? await FirestoreService.shared.getTransactions(for: userId)
        
        if let transactions = recentTransactions {
            // Verificar múltiplas transações em pouco tempo
            let recentCount = transactions.filter {
                Date().timeIntervalSince($0.date) < 300 // 5 minutos
            }.count
            
            if recentCount > 5 {
                await sendSecurityAlert("Múltiplas transações detectadas em pouco tempo")
                return false
            }
            
            // Verificar valores muito altos
            if transaction.amount > 10000 {
                await sendSecurityAlert("Transação de alto valor detectada: R$ \(transaction.amount)")
                // Pode exigir autenticação adicional
                return await requireAdditionalAuth()
            }
        }
        
        return true
    }
    
    private func requireAdditionalAuth() async -> Bool {
        let context = LAContext()
        let reason = "Confirme sua identidade para esta transação de alto valor"
        
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            return success
        } catch {
            return false
        }
    }
    
    private func sendSecurityAlert(_ message: String) async {
        await MainActor.run {
            NotificationService.shared.sendSecurityAlert(message: message)
        }
    }
}
