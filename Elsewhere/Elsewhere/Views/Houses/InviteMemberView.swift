//
//  InviteMemberView.swift
//  Elsewhere
//
//  Created on 2/8/26.
//

import SwiftUI

struct InviteMemberView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var selectedRole: HouseRole = .member
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Email Address") {
                    TextField("friend@example.com", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                }

                Section("Access Level") {
                    Picker("Role", selection: $selectedRole) {
                        ForEach(HouseRole.allCases, id: \.self) { role in
                            VStack(alignment: .leading) {
                                Text(role.displayName)
                            }
                            .tag(role)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()

                    Text(selectedRole.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }

                if let success = successMessage {
                    Section {
                        Text(success)
                            .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("Invite Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Send") {
                        sendInvitation()
                    }
                    .disabled(email.isEmpty || !isValidEmail(email) || isSending)
                }
            }
            .disabled(isSending)
            .overlay {
                if isSending {
                    ProgressView()
                }
            }
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    private func sendInvitation() {
        guard let userId = appState.currentUser?.id,
              let house = appState.currentHouse else {
            errorMessage = "Not signed in or no house selected"
            return
        }

        isSending = true
        errorMessage = nil
        successMessage = nil

        Task {
            do {
                let invitation = Invitation(
                    email: email.lowercased().trimmingCharacters(in: .whitespaces),
                    houseId: house.id,
                    houseName: house.name,
                    role: selectedRole,
                    invitedBy: userId,
                    inviterName: appState.currentUser?.displayName
                )

                try await FirebaseService.shared.createInvitation(invitation)

                await MainActor.run {
                    successMessage = "Invitation sent to \(email)"
                    isSending = false
                    email = ""

                    // Dismiss after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }

                print("✅ Invitation sent to \(invitation.email)")
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSending = false
                }
            }
        }
    }
}

#Preview {
    InviteMemberView(appState: AppState())
}
