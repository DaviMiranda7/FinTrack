//
//  ContentView.swift
//  FinTrack
//
//  Created by Davi Miranda on 31/07/25.
//

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
