//
//  HouseAccessView.swift
//  Elsewhere
//
//  Created on 2/8/26.
//

import SwiftUI

struct HouseAccessView: View {
    @ObservedObject var appState: AppState
    @State private var members: [HouseAccess] = []
    @State private var invitations: [Invitation] = []
    @State private var isLoading = true
    @State private var showInvite = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            // Current members section
            Section("Members") {
                if members.isEmpty && !isLoading {
                    Text("No members yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(members) { member in
                        MemberRow(
                            member: member,
                            isCurrentUser: member.userId == appState.currentUser?.id,
                            canManage: isCurrentUserOwner
                        ) {
                            removeMember(member)
                        }
                    }
                }
            }

            // Pending invitations section
            if !invitations.filter({ $0.status == .pending }).isEmpty {
                Section("Pending Invitations") {
                    ForEach(invitations.filter({ $0.status == .pending })) { invitation in
                        InvitationRow(invitation: invitation) {
                            cancelInvitation(invitation)
                        }
                    }
                }
            }

            // Invite section
            if isCurrentUserOwner {
                Section {
                    Button {
                        showInvite = true
                    } label: {
                        HStack {
                            Image(systemName: "person.badge.plus")
                                .foregroundColor(.blue)
                            Text("Invite Someone")
                        }
                    }
                }
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Members")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await loadData()
        }
        .task {
            await loadData()
        }
        .sheet(isPresented: $showInvite) {
            InviteMemberView(appState: appState)
        }
        .onChange(of: showInvite) { _, isPresented in
            if !isPresented {
                Task {
                    await loadData()
                }
            }
        }
    }

    private var isCurrentUserOwner: Bool {
        guard let userId = appState.currentUser?.id,
              let house = appState.currentHouse else {
            return false
        }
        return house.ownerIds.contains(userId)
    }

    private func loadData() async {
        guard let houseId = appState.currentHouse?.id else { return }

        isLoading = true
        errorMessage = nil

        do {
            async let membersResult = FirebaseService.shared.fetchHouseMembers(houseId: houseId)
            async let invitationsResult = FirebaseService.shared.fetchInvitations(forHouse: houseId)

            members = try await membersResult
            invitations = try await invitationsResult

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func removeMember(_ member: HouseAccess) {
        guard let houseId = appState.currentHouse?.id else { return }

        Task {
            do {
                try await FirebaseService.shared.removeUserFromHouse(
                    userId: member.userId,
                    houseId: houseId
                )
                await loadData()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func cancelInvitation(_ invitation: Invitation) {
        Task {
            do {
                try await FirebaseService.shared.deleteInvitation(invitation.id)
                await loadData()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct MemberRow: View {
    let member: HouseAccess
    let isCurrentUser: Bool
    let canManage: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(member.userName ?? member.userEmail ?? "Unknown")
                        .font(.headline)

                    if isCurrentUser {
                        Text("(You)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Text(member.role.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if canManage && !isCurrentUser {
                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }
}

struct InvitationRow: View {
    let invitation: Invitation
    let onCancel: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(invitation.email)
                    .font(.headline)

                Text("Invited as \(invitation.role.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(role: .destructive) {
                onCancel()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        HouseAccessView(appState: AppState())
    }
}
