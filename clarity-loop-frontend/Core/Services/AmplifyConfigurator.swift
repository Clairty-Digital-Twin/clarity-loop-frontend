import Amplify
import AWSCognitoAuthPlugin
import AWSAPIPlugin
import AWSS3StoragePlugin
import Foundation

enum AmplifyConfigurator {
    private static var isConfigured = false
    
    static func configure() {
        guard !isConfigured else { return }
        
        do {
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            try Amplify.add(plugin: AWSAPIPlugin())
            try Amplify.add(plugin: AWSS3StoragePlugin())
            try Amplify.configure()
            isConfigured = true
            print("✅ Amplify configured")
        } catch {
            print("❌ Amplify configuration error: \(error)")
            // In production, you might want to handle this more gracefully
            assertionFailure("❌ Amplify failed: \(error)")
        }
    }
}