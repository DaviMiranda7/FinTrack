import Foundation
import FirebaseAuth
import GoogleSignIn
import LocalAuthentication
import SwiftKeychainWrapper

class AuthService: ObservableObject {
    @Published var user: User?
    @Published var isAuthenticated = false
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    init() {
        authStateListener = Auth.auth().addStateDidChangeListener { _, user in
            self.isAuthenticated = user != nil
        }
    }
    
    //Login apenas com email e senha
    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
        
        // Salvar credenciais no Keychain para Face ID
        let emailSaved = KeychainWrapper.standard.set(email, forKey: "userEmail")
        let passwordSaved = KeychainWrapper.standard.set(password, forKey: "userPassword")
        
        print("Email saved to keychain: \(emailSaved)")
        print("Password saved to keychain: \(passwordSaved)")
    }

    //Login com faceID
    func signInWithBiometrics() async throws {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw NSError(domain: "BiometricError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Face ID não disponível"])
        }
        
        let reason = "Use Face ID para acessar o FinTrack"
        
        let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
        
        if success {
            // Recuperar credenciais do Keychain
            guard let savedEmail = KeychainWrapper.standard.string(forKey: "userEmail"),
                  let savedPassword = KeychainWrapper.standard.string(forKey: "userPassword") else {
                throw NSError(domain: "BiometricError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Nenhuma credencial salva. Faça login primeiro."])
            }
            
            try await Auth.auth().signIn(withEmail: savedEmail, password: savedPassword)
        }
    }
    
    //Login com Email Google
    func signInWithGoogle() async throws {
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = await windowScene.windows.first,
              let rootViewController = await window.rootViewController else {
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No presenting view controller"])
        }
        
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        
        guard let idToken = result.user.idToken?.tokenString else {
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to get ID token"])
        }
        
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString)
        let authResult = try await Auth.auth().signIn(with: credential)
        
        // Criar usuário no Firestore se não existir
        let newUser = User(
            id: authResult.user.uid,
            name: authResult.user.displayName ?? "Usuário Google",
            email: authResult.user.email ?? ""
        )
        
        // Verificar se usuário já existe
        let existingUser = try? await FirestoreService.shared.getUser(id: authResult.user.uid)
        if existingUser == nil {
            try await FirestoreService.shared.saveUser(newUser)
        }
    }

    //Registrar apenas com email e senha
    func signUp(email: String, password: String, name: String) async throws {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let newUser = User(
                id: result.user.uid,
                name: name,
                email: email,
                balance: 0.0,
                createdAt: Date()
            )
            try await FirestoreService.shared.saveUser(newUser)
            
            // Salvar credenciais no Keychain
            KeychainWrapper.standard.set(email, forKey: "userEmail")
            KeychainWrapper.standard.set(password, forKey: "userPassword")
            
        } catch let error as NSError {
            print("Erro detalhado: \(error.localizedDescription)")
            throw error
        }
    }
    
    //Funcao para deslogar
    func signOut() throws {
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
        
        // Limpar credenciais do Keychain
        KeychainWrapper.standard.removeObject(forKey: "userEmail")
        KeychainWrapper.standard.removeObject(forKey: "userPassword")
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
}
