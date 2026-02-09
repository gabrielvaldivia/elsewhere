//
//  MaintenanceView.swift
//  Elsewhere
//
//  Created on 2/8/26.
//

import SwiftUI

struct MaintenanceView: View {
    @ObservedObject var appState: AppState
    @State private var items: [MaintenanceItem] = []
    @State private var isLoading = true
    @State private var showAddItem = false
    @State private var selectedFilter: MaintenanceFilter = .pending
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Filter picker
            Picker("Filter", selection: $selectedFilter) {
                ForEach(MaintenanceFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Items list
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if filteredItems.isEmpty {
                Spacer()
                EmptyMaintenanceView(filter: selectedFilter)
                Spacer()
            } else {
                List {
                    ForEach(filteredItems) { item in
                        NavigationLink {
                            MaintenanceDetailView(appState: appState, item: item) {
                                Task {
                                    await loadItems()
                                }
                            }
                        } label: {
                            MaintenanceItemRow(item: item, onToggleComplete: {
                                toggleComplete(item)
                            })
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Maintenance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddItem = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            await loadItems()
        }
        .refreshable {
            await loadItems()
        }
        .sheet(isPresented: $showAddItem) {
            AddMaintenanceView(appState: appState) {
                Task {
                    await loadItems()
                }
            }
        }
    }

    private var filteredItems: [MaintenanceItem] {
        switch selectedFilter {
        case .pending:
            return items.filter { $0.status == .pending || $0.status == .inProgress }
        case .completed:
            return items.filter { $0.status == .completed }
        case .all:
            return items
        }
    }

    private func loadItems() async {
        guard let houseId = appState.currentHouse?.id else { return }

        isLoading = true
        errorMessage = nil

        do {
            items = try await FirebaseService.shared.fetchMaintenanceItems(houseId: houseId)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func toggleComplete(_ item: MaintenanceItem) {
        Task {
            var updated = item
            updated.status = item.status == .completed ? .pending : .completed
            updated.completedAt = updated.status == .completed ? Date() : nil
            updated.updatedAt = Date()
            try? await FirebaseService.shared.saveMaintenanceItem(updated)
            await loadItems()
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        let itemsToDelete = offsets.map { filteredItems[$0] }

        Task {
            for item in itemsToDelete {
                do {
                    try await FirebaseService.shared.deleteMaintenanceItem(item.id)
                } catch {
                    print("Failed to delete item: \(error)")
                }
            }
            await loadItems()
        }
    }
}

enum MaintenanceFilter: String, CaseIterable {
    case pending = "Pending"
    case completed = "Completed"
    case all = "All"
}

struct MaintenanceItemRow: View {
    let item: MaintenanceItem
    var onToggleComplete: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            // Radio button
            Button {
                onToggleComplete?()
            } label: {
                Image(systemName: item.status == .completed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(item.status == .completed ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .strikethrough(item.status == .completed)
                    .foregroundColor(item.status == .completed ? .secondary : .primary)

                if let dueDate = item.dueDate {
                    Text("Due \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(isOverdue ? .red : .secondary)
                }
            }

            Spacer()

            // Priority indicator
            Circle()
                .fill(priorityColor)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
    }

    private var priorityColor: Color {
        switch item.priority {
        case .urgent:
            return .red
        case .high:
            return .orange
        case .medium:
            return .yellow
        case .low:
            return .green
        }
    }

    private var isOverdue: Bool {
        guard let dueDate = item.dueDate else { return false }
        return dueDate < Date() && item.status != .completed
    }
}

struct EmptyMaintenanceView: View {
    let filter: MaintenanceFilter

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(emptyMessage)
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var emptyMessage: String {
        switch filter {
        case .pending:
            return "No pending tasks"
        case .completed:
            return "No completed tasks yet"
        case .all:
            return "No maintenance items"
        }
    }
}

#Preview {
    MaintenanceView(appState: AppState())
}
