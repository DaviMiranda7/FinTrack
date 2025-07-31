import SwiftUI

struct ContentView: View {
    @StateObject private var authService = AuthService()
    
    var body: some View {
        if authService.isAuthenticated {
            DashboardView()
        } else {
            LoginView()
        }
    }
}


#Preview {
    ContentView()
}
