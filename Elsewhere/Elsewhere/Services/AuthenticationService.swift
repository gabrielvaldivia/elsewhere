//
//  AuthenticationService.swift
//  Elsewhere
//
//  Created on 2/8/26.
//

import Foundation
import Combine
import AuthenticationServices
import CryptoKit
import FirebaseAuth

@MainActor
class AuthenticationService: NSObject, ObservableObject {
    static let shared = AuthenticationService()

    @Published var isSigningIn = false
    @Published var errorMessage: String?

    private var currentNonce: String?
    private var signInContinuation: CheckedContinuation<User, Error>?

    private override init() {
        super.init()
    }

    // MARK: - Sign in with Apple

    func signInWithApple() async throws -> User {
        isSigningIn = true
        errorMessage = nil

        defer {
            isSigningIn = false
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.signInContinuation = continuation

            let nonce = randomNonceString()
            currentNonce = nonce

            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)

            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.performRequests()
        }
    }

    // MARK: - Link Anonymous Account to Apple

    func linkAppleAccount() async throws -> User {
        isSigningIn = true
        errorMessage = nil

        defer {
            isSigningIn = false
        }

        guard Auth.auth().currentUser?.isAnonymous == true else {
            throw AuthenticationError.notAnonymousUser
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.signInContinuation = continuation

            let nonce = randomNonceString()
            currentNonce = nonce

            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)

            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.performRequests()
        }
    }

    // MARK: - Sign Out

    func signOut() throws {
        try Auth.auth().signOut()
    }

    // MARK: - Check Auth State

    func getCurrentUser() -> User? {
        guard let firebaseUser = Auth.auth().currentUser else {
            return nil
        }

        return User(
            id: firebaseUser.uid,
            email: firebaseUser.email ?? "",
            displayName: firebaseUser.displayName,
            createdAt: firebaseUser.metadata.creationDate ?? Date(),
            isAnonymous: firebaseUser.isAnonymous,
            appleUserId: nil,
            photoURL: firebaseUser.photoURL?.absoluteString
        )
    }

    // MARK: - Helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }

        return String(nonce)
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()

        return hashString
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthenticationService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            do {
                guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                    throw AuthenticationError.invalidCredential
                }

                guard let nonce = currentNonce else {
                    throw AuthenticationError.invalidNonce
                }

                guard let appleIDToken = appleIDCredential.identityToken else {
                    throw AuthenticationError.missingIDToken
                }

                guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                    throw AuthenticationError.invalidIDToken
                }

                let credential = OAuthProvider.appleCredential(
                    withIDToken: idTokenString,
                    rawNonce: nonce,
                    fullName: appleIDCredential.fullName
                )

                let authResult: AuthDataResult

                // Check if we should link to existing anonymous account
                if let currentUser = Auth.auth().currentUser, currentUser.isAnonymous {
                    // Link the Apple credential to the anonymous account
                    authResult = try await currentUser.link(with: credential)
                    print("✅ Linked Apple credential to anonymous account")
                } else {
                    // Sign in directly with Apple credential
                    authResult = try await Auth.auth().signIn(with: credential)
                    print("✅ Signed in with Apple credential")
                }

                let firebaseUser = authResult.user

                // Get display name from Apple credential if available
                var displayName = firebaseUser.displayName
                if displayName == nil || displayName?.isEmpty == true {
                    if let fullName = appleIDCredential.fullName {
                        let formatter = PersonNameComponentsFormatter()
                        displayName = formatter.string(from: fullName)
                    }
                }

                // Update profile if we have a display name
                if let name = displayName, !name.isEmpty, firebaseUser.displayName != name {
                    let changeRequest = firebaseUser.createProfileChangeRequest()
                    changeRequest.displayName = name
                    try? await changeRequest.commitChanges()
                }

                let user = User(
                    id: firebaseUser.uid,
                    email: firebaseUser.email ?? appleIDCredential.email ?? "",
                    displayName: displayName,
                    createdAt: firebaseUser.metadata.creationDate ?? Date(),
                    isAnonymous: false,
                    appleUserId: appleIDCredential.user,
                    photoURL: firebaseUser.photoURL?.absoluteString
                )

                // Save user to Firestore
                try await FirebaseService.shared.saveUser(user)

                signInContinuation?.resume(returning: user)
                signInContinuation = nil
                currentNonce = nil

            } catch {
                print("❌ Apple Sign In error: \(error)")
                errorMessage = error.localizedDescription
                signInContinuation?.resume(throwing: error)
                signInContinuation = nil
                currentNonce = nil
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("❌ Apple Sign In failed: \(error)")

        let authError: AuthenticationError
        if let asError = error as? ASAuthorizationError {
            switch asError.code {
            case .canceled:
                authError = .userCancelled
            case .failed:
                authError = .authorizationFailed
            case .invalidResponse:
                authError = .invalidResponse
            case .notHandled:
                authError = .notHandled
            case .notInteractive:
                authError = .notInteractive
            case .unknown:
                fallthrough
            case .matchedExcludedCredential:
                fallthrough
            @unknown default:
                authError = .unknown
            }
        } else {
            authError = .unknown
        }

        errorMessage = authError.localizedDescription
        signInContinuation?.resume(throwing: authError)
        signInContinuation = nil
        currentNonce = nil
    }
}

// MARK: - Errors

enum AuthenticationError: LocalizedError {
    case invalidCredential
    case invalidNonce
    case missingIDToken
    case invalidIDToken
    case notAnonymousUser
    case userCancelled
    case authorizationFailed
    case invalidResponse
    case notHandled
    case notInteractive
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid credential received from Apple"
        case .invalidNonce:
            return "Invalid authentication state"
        case .missingIDToken:
            return "Missing identity token from Apple"
        case .invalidIDToken:
            return "Invalid identity token format"
        case .notAnonymousUser:
            return "Cannot link - user is not anonymous"
        case .userCancelled:
            return "Sign in was cancelled"
        case .authorizationFailed:
            return "Authorization failed"
        case .invalidResponse:
            return "Invalid response from Apple"
        case .notHandled:
            return "Authorization request not handled"
        case .notInteractive:
            return "Authorization requires user interaction"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}
