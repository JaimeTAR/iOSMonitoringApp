import SwiftUI
import Combine

/// Invitation code management: generate, filter, copy, and revoke codes
struct InvitationManagerView: View {
    @StateObject var viewModel: InvitationManagerViewModel
    @State private var showCopiedToast = false
    @State private var codeToRevoke: InvitationCode?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.invitationCodes.isEmpty {
                    loadingView
                } else {
                    contentView
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Invitations")
            .refreshable { await viewModel.refresh() }
            .task { await viewModel.loadData() }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") { viewModel.error = nil }
            } message: {
                Text(viewModel.error ?? "An error occurred")
            }
            .alert("Revoke Code?", isPresented: Binding(
                get: { codeToRevoke != nil },
                set: { if !$0 { codeToRevoke = nil } }
            )) {
                Button("Cancel", role: .cancel) { codeToRevoke = nil }
                Button("Revoke", role: .destructive) {
                    if let code = codeToRevoke {
                        Task { await viewModel.revokeCode(id: code.id) }
                        codeToRevoke = nil
                    }
                }
            } message: {
                Text("This code will no longer be usable. This action can't be undone.")
            }
            .overlay(alignment: .bottom) {
                if showCopiedToast {
                    copiedToast
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Content

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 16) {
                generateButton
                statusCounterRow
                statusFilter
                codeList
            }
            .padding()
        }
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        Button {
            Task { await viewModel.generateCode() }
        } label: {
            Label("Generate Code", systemImage: "plus.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.appPrimary)
    }

    // MARK: - Status Counter

    private var statusCounterRow: some View {
        HStack(spacing: 12) {
            counterItem("Pending", count: viewModel.statusCounts.pending, color: .statusYellow)
            counterItem("Used", count: viewModel.statusCounts.used, color: .statusGreen)
            counterItem("Expired", count: viewModel.statusCounts.expired, color: .statusRed)
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(12)
    }

    private func counterItem(_ label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.appHeadline)
                .foregroundColor(color)
            Text(label)
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Status Filter

    private var statusFilter: some View {
        Picker("Filter", selection: $viewModel.statusFilter) {
            ForEach(InvitationStatusFilter.allCases, id: \.self) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Code List

    private var codeList: some View {
        VStack(spacing: 8) {
            if viewModel.filteredCodes.isEmpty {
                Text("No invitation codes match this filter.")
                    .font(.appBody)
                    .foregroundColor(.appTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                ForEach(viewModel.filteredCodes) { code in
                    invitationCard(code)
                }
            }
        }
    }

    private func invitationCard(_ code: InvitationCode) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text(code.code)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.appTextPrimary)
                Spacer()
                StatusBadge(status: code.status)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Created: \(formattedDate(code.createdAt))")
                        .font(.appCaption)
                        .foregroundColor(.appTextSecondary)
                    Text("Expires: \(formattedDate(code.expiresAt))")
                        .font(.appCaption)
                        .foregroundColor(.appTextSecondary)
                }
                Spacer()
            }

            HStack(spacing: 12) {
                Button {
                    viewModel.copyToClipboard(code: code.code)
                    withAnimation { showCopiedToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { showCopiedToast = false }
                    }
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.appCaption)
                }
                .buttonStyle(.bordered)

                if InvitationManagerViewModel.canRevoke(code) {
                    Button(role: .destructive) {
                        codeToRevoke = code
                    } label: {
                        Label("Revoke", systemImage: "xmark.circle")
                            .font(.appCaption)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(12)
    }

    // MARK: - Toast

    private var copiedToast: some View {
        Text("Code copied to clipboard")
            .font(.appCallout)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.8))
            .cornerRadius(20)
            .padding(.bottom, 24)
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.2)
            Text("Loading invitations...")
                .font(.appBody)
                .foregroundColor(.appTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    private func formattedDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }
}
