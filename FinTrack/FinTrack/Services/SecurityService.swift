import Foundation
import FirebaseAuth
import FirebaseFirestore
import CoreLocation
import LocalAuthentication
import DeviceCheck

class SecurityService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = SecurityService() // Singleton para uso único na aplicação
    private let locationManager = CLLocationManager() // Gerencia localização do dispositivo
    private let db = Firestore.firestore() // Instância do Firestore para salvar dados
    
    //Variaveis para seguraca
    private var previousLocations: [CLLocation] = [] 
    private let maxSpeedThreshold: CLLocationSpeed = 300
    private let minDistanceThreshold: CLLocationDistance = 1000
    private let timeWindow: TimeInterval = 10 * 60
    
    @Published var isDeviceSecure = true
    @Published var locationAuthorized = false
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest // Melhor precisão possível
    }
    
    // Verifica se o dispositivo atende aos critérios de segurança básicos
    func checkDeviceSecurity() async -> Bool {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            await sendSecurityAlert("Dispositivo sem biometria detectado")
            return false
        }
        
        if isJailbroken() {
            await sendSecurityAlert("Dispositivo com jailbreak detectado")
            return false
        }
        
        if #available(iOS 11.0, *) {
            let deviceCheck = DCDevice.current
            if deviceCheck.isSupported {
            }
        }
        
        return true
    }
    
    // Checa se existem evidências de jailbreak no dispositivo
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
    
    // MARK: - Localização
    
    // Solicita permissão para acessar localização do usuário
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    // Inicia o rastreamento da localização caso tenha permissão
    func startLocationTracking() {
        guard locationAuthorized else { return }
        locationManager.startUpdatingLocation()
    }
    
    // Atualiza localizações recebidas e salva no banco
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last,
              let userId = Auth.auth().currentUser?.uid else { return }
        
        let locationData: [String: Any] = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "timestamp": Date(),
            "accuracy": location.horizontalAccuracy
        ]
        
        db.collection("users").document(userId).collection("locations").addDocument(data: locationData)
        
        checkSuspiciousLocation(location)
    }
    
    // Atualiza o estado da permissão de localização conforme o usuário altera
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        locationAuthorized = status == .authorizedWhenInUse || status == .authorizedAlways
    }

    // Verifica se a localização atual indica comportamento suspeito
    private func checkSuspiciousLocation(_ location: CLLocation) -> Bool {
        guard location.horizontalAccuracy >= 0 else { return false }
        
        previousLocations.append(location)
        
        previousLocations = previousLocations.filter {
            abs($0.timestamp.timeIntervalSinceNow) <= timeWindow
        }
        
        // Precisa de pelo menos duas localizações para comparar
        guard previousLocations.count >= 2 else { return false }
        
        let currentLocation = previousLocations.last!
        let previousLocation = previousLocations[previousLocations.count - 2]
        
        // Calcula distância e intervalo de tempo entre as duas localizações
        let distance = currentLocation.distance(from: previousLocation)
        let timeInterval = currentLocation.timestamp.timeIntervalSince(previousLocation.timestamp)
        
        // Verifica se a velocidade ultrapassa o limite aceitável
        if timeInterval > 0 {
            let speed = distance / timeInterval
            
            if speed > maxSpeedThreshold {
                Task {
                    await sendSecurityAlert("Velocidade suspeita detectada: \(Int(speed * 3.6)) km/h. Possível uso não autorizado.")
                }
                return true
            }
        }
        
        // Detecta saltos grandes de localização em curto intervalo de tempo
        if distance > minDistanceThreshold && timeInterval < 60 {
            Task {
                await sendSecurityAlert("Mudança de localização suspeita: \(Int(distance))m em \(Int(timeInterval))s. Possível clonagem de dispositivo.")
            }
            return true
        }
        
        // Verifica mudança brusca de altitude num curto espaço de tempo
        if abs(currentLocation.altitude - previousLocation.altitude) > 1000 && timeInterval < 60 {
            Task {
                await sendSecurityAlert("Mudança de altitude suspeita detectada. Verificação de segurança necessária.")
            }
            return true
        }
        
        return false
    }
    
    // MARK: - Segurança nas transações
    
    // Valida uma transação verificando padrões suspeitos
    func validateTransaction(_ transaction: Transaction) async -> Bool {
        guard let userId = Auth.auth().currentUser?.uid else { return false }
        
        // Busca transações recentes do usuário para análise
        let recentTransactions = try? await FirestoreService.shared.getTransactions(for: userId)
        
        if let transactions = recentTransactions {
            // Verifica se houve muitas transações em pouco tempo
            let recentCount = transactions.filter {
                Date().timeIntervalSince($0.date) < 300 // últimos 5 minutos
            }.count
            
            if recentCount > 5 {
                await sendSecurityAlert("Múltiplas transações detectadas em pouco tempo")
                return false
            }
            
            // Verifica transações com valores altos
            if transaction.amount > 10000 {
                await sendSecurityAlert("Transação de alto valor detectada: R$ \(transaction.amount)")
                // Pode pedir autenticação extra para confirmar
                return await requireAdditionalAuth()
            }
        }
        
        return true
    }
    
    // Solicita autenticação biométrica para confirmar ações sensíveis
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
    
    // Envia alerta de segurança via serviço de notificações
    private func sendSecurityAlert(_ message: String) async {
        await MainActor.run {
            NotificationService.shared.sendSecurityAlert(message: message)
        }
    }
}
