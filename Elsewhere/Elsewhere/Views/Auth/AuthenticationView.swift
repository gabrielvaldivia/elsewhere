//
//  AuthenticationView.swift
//  Elsewhere
//
//  Created on 2/8/26.
//

import SwiftUI
import AuthenticationServices

struct AuthenticationView: View {
    @ObservedObject var appState: AppState
    @StateObject private var authService = AuthenticationService.shared
    @State private var showError = false

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Logo and Title
            VStack(spacing: 16) {
                Image(systemName: "house.lodge.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)

                Text("Elsewhere")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Your second home copilot")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Sign In Buttons
            VStack(spacing: 16) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleAppleSignIn(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .cornerRadius(8)

                Button(action: continueAnonymously) {
                    Text("Continue without account")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .disabled(authService.isSigningIn)
            }
            .padding(.horizontal, 32)

            if authService.isSigningIn {
                ProgressView()
                    .padding()
            }

            Spacer()
                .frame(height: 60)
        }
        .alert("Sign In Error", isPresented: $showError) {
            Button("OK") {
                showError = false
            }
        } message: {
            Text(authService.errorMessage ?? "An unknown error occurred")
        }
        .onChange(of: authService.errorMessage) { _, newValue in
            if newValue != nil {
                showError = true
            }
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        Task {
            do {
                let user = try await authService.signInWithApple()
                await MainActor.run {
                    appState.handleSuccessfulSignIn(user)
                }
            } catch {
                if case AuthenticationError.userCancelled = error {
                    // User cancelled, don't show error
                    return
                }
                print("Apple Sign In error: \(error)")
            }
        }
    }

    private func continueAnonymously() {
        Task {
            await appState.signInAnonymously()
        }
    }
}

#Preview {
    AuthenticationView(appState: AppState())
}
