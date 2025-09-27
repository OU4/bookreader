//
//  AppDelegate.swift
//  BookReader
//
//  Created by Abdulaziz dot on 28/07/2025.
//
import UIKit
import Firebase
import FirebaseAuth

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Configure Firebase
        FirebaseApp.configure()
        
        // Enable Firestore offline persistence (must be done before first use)
        let db = Firestore.firestore()
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        db.settings = settings
        
        // Create window
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.backgroundColor = .systemBackground
        
        // Check authentication state and show appropriate view
        let currentUser = Auth.auth().currentUser
        
        if let user = currentUser {
            // User is signed in, show library
            let libraryVC = ModernLibraryViewController()
            let navigationController = UINavigationController(rootViewController: libraryVC)
            window?.rootViewController = navigationController
            
            // Check if migration is needed
            checkForMigration()
        } else {
            // No user signed in, show auth screen
            let loginVC = LoginViewController()
            let navigationController = UINavigationController(rootViewController: loginVC)
            navigationController.isNavigationBarHidden = true
            window?.rootViewController = navigationController
        }
        
        // Make window key and visible
        window?.makeKeyAndVisible()
        
        return true
    }
    
    // MARK: - Migration
    private func checkForMigration() {
        // Check if user has already migrated or skipped
        let hasMigrated = UserDefaults.standard.bool(forKey: "HasMigratedToFirebase")
        let hasSkipped = UserDefaults.standard.bool(forKey: "HasSkippedMigration")
        
        if !hasMigrated && !hasSkipped {
            // Check if there are local books to migrate
            let localBooks = BookStorage.shared.loadBooks()
            if !localBooks.isEmpty {
                // Show migration view
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    let migrationVC = MigrationViewController()
                    migrationVC.modalPresentationStyle = .overFullScreen
                    migrationVC.modalTransitionStyle = .crossDissolve
                    self?.window?.rootViewController?.present(migrationVC, animated: true)
                }
            }
        }
    }
}
