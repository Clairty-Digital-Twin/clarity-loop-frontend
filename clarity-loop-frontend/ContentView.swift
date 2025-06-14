//
//  ContentView.swift
//  clarity-loop-frontend
//
//  Created by Raymond Jung on 6/6/25.
//

import SwiftUI

struct ContentView: View {
    @Environment(AuthViewModel.self) private var authViewModel

    var body: some View {
        VStack {
            Text("🎉 CLARITY PULSE")
                .font(.largeTitle)
                .padding()
            
            if authViewModel.isLoggedIn {
                Text("✅ User is logged in!")
                    .foregroundColor(.green)
                // MainTabView() // Commented out to avoid healthDataRepository access
            } else {
                Text("❌ User not logged in")
                    .foregroundColor(.orange)
                // LoginView would go here but commenting out to test auth only
            }
        }
    }
}


#if DEBUG
// NOTE: The preview is temporarily simplified to ensure the project builds.
// Mocking FirebaseAuth.User is complex due to non-public initializers and
// causes the build to fail. A robust mocking strategy will be implemented later.
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Text("ContentView Preview (Disabled)")
    }
}
#else
#Preview {
    Text("Preview not available.")
}
#endif
