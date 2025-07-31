import SwiftUI
import SwiftKeychainWrapper
import LocalAuthentication

struct LoginView: View {
    @StateObject private var authService = AuthService()
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isSignUp = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var canUseBiometrics = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("FinTrack")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 40)
            
            VStack(spacing: 15) {
                if isSignUp {
                    TextField("Nome", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                
                SecureField("Senha", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)
            
            Button(action: handleAuth) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(isSignUp ? "Cadastrar" : "Entrar")
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.horizontal)
            .disabled(isLoading)
            
            // Login com Google
            Button(action: signInWithGoogle) {
                HStack {
                    Image(systemName: "globe")
                    Text("Entrar com Google")
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.horizontal)
            .disabled(isLoading)
            
            // Login com Biometria
            if canUseBiometrics && !isSignUp {
                Button(action: signInWithBiometrics) {
                    HStack {
                        Image(systemName: "faceid")
                        Text("Entrar com Face ID")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled(isLoading)
            }
            
            Button(action: { isSignUp.toggle() }) {
                Text(isSignUp ? "Já tem conta? Entrar" : "Não tem conta? Cadastrar")
                    .foregroundColor(.blue)
            }
            
            Spacer()
        }
        .onAppear {
            checkBiometricAvailability()
        }
        .alert("Erro", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func handleAuth() {
        isLoading = true
        
        Task {
            do {
                if isSignUp {
                    try await authService.signUp(email: email, password: password, name: name)
                } else {
                    try await authService.signIn(email: email, password: password)
                    
                    // Aguardar e atualizar UI
                    try await Task.sleep(nanoseconds: 500_000_000)
                    await MainActor.run {
                        checkBiometricAvailability()
                        // Forçar atualização da UI
                        canUseBiometrics = KeychainWrapper.standard.string(forKey: "userEmail") != nil
                    }
                }
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }



    
    private func signInWithGoogle() {
        isLoading = true
        
        Task {
            do {
                try await authService.signInWithGoogle()
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func signInWithBiometrics() {
        isLoading = true
        
        Task {
            do {
                try await authService.signInWithBiometrics()
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        
        let biometricAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        // Debug detalhado
        let email = KeychainWrapper.standard.string(forKey: "userEmail")
        let password = KeychainWrapper.standard.string(forKey: "userPassword")
        
        print("=== FACE ID DEBUG ===")
        print("Biometric available: \(biometricAvailable)")
        print("Email from keychain: \(email ?? "nil")")
        print("Password from keychain: \(password != nil ? "exists" : "nil")")
        print("Has credentials: \(email != nil)")
        print("====================")
        
        let hasCredentials = email != nil
        canUseBiometrics = biometricAvailable && hasCredentials
    }


}
