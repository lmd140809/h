import SwiftUI

struct PatchUpdateSheet: View {
    @ObservedObject var manager: PatchUpdateManager
    @Environment(\.dismiss) private var dismiss
    @State private var installing: PatchUpdate?
    @State private var showSuccess = false
    @State private var errorMsg = ""
    @State private var showError = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                contentView
            }
            .navigationTitle("Cập nhật Patch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Đóng") { dismiss() }.foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Xoá") {
                        manager.availableUpdates.removeAll()
                        dismiss()
                    }.foregroundStyle(.red)
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("Thành công", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Đã cài đặt patch mới. Vui lòng tắt App và mở lại để áp dụng.")
        }
        .alert("Lỗi", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMsg)
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if manager.availableUpdates.isEmpty {
            VStack {
                Spacer()
                Text("Không có bản cập nhật mới.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
            }
        } else {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(manager.availableUpdates) { update in
                        updateRow(update)
                    }
                }
                .padding()
            }
        }
    }

    private func updateRow(_ update: PatchUpdate) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(update.filename)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("Version: \(update.version) • \(update.sizeFormatted)")
                        .font(.system(size: 11))
                        .foregroundStyle(.gray)
                }
                Spacer()
            }
            
            if let notes = update.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            if installing?.id == update.id {
                ProgressView(value: manager.downloadProgress).tint(.blue)
            } else {
                Button {
                    Task { await install(update) }
                } label: {
                    Text("TẢI VỀ VÀ CÀI ĐẶT")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
    }

    private func install(_ update: PatchUpdate) async {
        installing = update
        do {
            try await manager.downloadAndInstall(update)
            installing = nil
            showSuccess = true
        } catch {
            installing = nil
            errorMsg = error.localizedDescription
            showError = true
        }
    }
}
