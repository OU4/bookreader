//
//  AuthenticationManager.swift
//  BookReader
//
//  Handles all authentication operations
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices
import CryptoKit
import Combine

class AuthenticationManager: NSObject, ObservableObject {
    
    // MARK: - Singleton
    static let shared = AuthenticationManager()
    
    // MARK: - Properties
    private var currentNonce: String?
    private var appleSignInCompletion: ((Result<User, Error>) -> Void)?
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    // MARK: - Published Properties
    @Published var user: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Init
    private override init() {
        super.init()
        setupAuthStateListener()
    }
    
    // MARK: - Setup
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            self?.user = user
            self?.isAuthenticated = user != nil
            
            if let user = user {
                // Update last login time
                self?.updateLastLoginTime()
            } else {
            }
        }
    }
    
    // MARK: - Sign In Methods
    
    // Email/Password Sign In
    func signIn(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        isLoading = true
        errorMessage = nil
        
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            self?.isLoading = false
            
            if let error = error {
                self?.errorMessage = error.localizedDescription
                completion(.failure(error))
                return
            }
            
            if let user = result?.user {
                completion(.success(user))
            } else {
                let error = NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error occurred"])
                completion(.failure(error))
            }
        }
    }
    
    // Email/Password Sign Up
    func signUp(email: String, password: String, displayName: String, completion: @escaping (Result<User, Error>) -> Void) {
        isLoading = true
        errorMessage = nil
        
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                self?.isLoading = false
                self?.errorMessage = error.localizedDescription
                completion(.failure(error))
                return
            }
            
            // Update display name
            if let user = result?.user {
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = displayName
                changeRequest.commitChanges { error in
                    self?.isLoading = false
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                        completion(.failure(error))
                    } else {
                        completion(.success(user))
                    }
                }
            }
        }
    }
    
    // Anonymous Sign In
    func signInAnonymously(completion: @escaping (Result<User, Error>) -> Void) {
        isLoading = true
        errorMessage = nil
        
        Auth.auth().signInAnonymously { [weak self] result, error in
            self?.isLoading = false
            
            if let error = error {
                self?.errorMessage = error.localizedDescription
                completion(.failure(error))
                return
            }
            
            if let user = result?.user {
                completion(.success(user))
            } else {
                let error = NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to sign in anonymously"])
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Sign In with Apple
    func startSignInWithAppleFlow(completion: @escaping (Result<User, Error>) -> Void) {
        appleSignInCompletion = completion
        guard let nonce = randomNonceString() else {
            let error = AuthenticationError.nonceGenerationFailed
            errorMessage = error.localizedDescription
            completion(.failure(error))
            appleSignInCompletion = nil
            return
        }
        currentNonce = nonce
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    // MARK: - Password Reset
    func resetPassword(email: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Sign Out
    func signOut(completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            try Auth.auth().signOut()
            completion(.success(()))
        } catch {
            errorMessage = error.localizedDescription
            completion(.failure(error))
        }
    }
    
    // MARK: - Account Management
    func deleteAccount(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(.failure(NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])))
            return
        }
        
        user.delete { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Helper Methods
    private func updateLastLoginTime() {
        guard let userId = user?.uid else { return }
        
        let userRef = Firestore.firestore().collection("users").document(userId)
        userRef.updateData([
            "lastLoginTime": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
            }
        }
    }
    
    // MARK: - Apple Sign In Helpers
    private func randomNonceString(length: Int = 32) -> String? {
        guard length > 0 else { return nil }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        guard !charset.isEmpty else { return nil }
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)

            let index: Int
            if status == errSecSuccess {
                index = Int(random) % charset.count
            } else {
                index = Int.random(in: 0..<charset.count)
            }

            result.append(charset[index])
            remainingLength -= 1
        }

        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            return String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AuthenticationManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            return
        }

        guard let nonce = currentNonce else {
            let error = AuthenticationError.invalidNonceState
            errorMessage = error.localizedDescription
            appleSignInCompletion?(.failure(error))
            appleSignInCompletion = nil
            return
        }

        guard let appleIDToken = appleIDCredential.identityToken else {
            let error = AuthenticationError.missingIdentityToken
            errorMessage = error.localizedDescription
            appleSignInCompletion?(.failure(error))
            appleSignInCompletion = nil
            currentNonce = nil
            return
        }

        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            let error = AuthenticationError.invalidIdentityTokenEncoding
            errorMessage = error.localizedDescription
            appleSignInCompletion?(.failure(error))
            appleSignInCompletion = nil
            currentNonce = nil
            return
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        Auth.auth().signIn(with: credential) { [weak self] authResult, error in
            guard let self = self else { return }
            self.currentNonce = nil

            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.appleSignInCompletion?(.failure(error))
                    self.appleSignInCompletion = nil
                }
                return
            }

            guard let user = authResult?.user else {
                let error = AuthenticationError.missingAuthResult
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.appleSignInCompletion?(.failure(error))
                    self.appleSignInCompletion = nil
                }
                return
            }

            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = appleIDCredential.fullName?.givenName
            changeRequest.commitChanges { [weak self] commitError in
                guard let self = self, let commitError = commitError else { return }
                DispatchQueue.main.async {
                    self.errorMessage = commitError.localizedDescription
                }
            }

            DispatchQueue.main.async {
                self.appleSignInCompletion?(.success(user))
                self.appleSignInCompletion = nil
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = error.localizedDescription
            self.appleSignInCompletion?(.failure(error))
            self.appleSignInCompletion = nil
            self.currentNonce = nil
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension AuthenticationManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) {
            return window
        }

        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first {
            return window
        }

        if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
            return window
        }

        return UIWindow(frame: UIScreen.main.bounds)
    }
}

// MARK: - Authentication Errors
enum AuthenticationError: LocalizedError {
    case nonceGenerationFailed
    case invalidNonceState
    case missingIdentityToken
    case invalidIdentityTokenEncoding
    case missingAuthResult

    var errorDescription: String? {
        switch self {
        case .nonceGenerationFailed:
            return "Unable to start Sign in with Apple. Please try again."
        case .invalidNonceState:
            return "Authentication flow is no longer valid. Please retry."
        case .missingIdentityToken:
            return "Unable to retrieve Apple ID token."
        case .invalidIdentityTokenEncoding:
            return "Received an invalid identity token."
        case .missingAuthResult:
            return "Failed to complete Sign in with Apple."
        }
    }
}
