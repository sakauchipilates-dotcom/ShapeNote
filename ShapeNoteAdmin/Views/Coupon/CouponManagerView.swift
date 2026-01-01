import SwiftUI

struct CouponManagerView: View {
    @StateObject private var vm = CouponManagerVM()

    // 会員詳細から渡せるように
    private let preselectedUserId: String
    private let preselectedUserName: String

    @State private var editingCoupon: CouponManagerVM.AdminCoupon?
    @State private var showEditSheet = false

    @State private var deleteTarget: CouponManagerVM.AdminCoupon?
    @State private var showDeleteConfirm = false

    init(preselectedUserId: String = "", preselectedUserName: String = "") {
        self.preselectedUserId = preselectedUserId
        self.preselectedUserName = preselectedUserName
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 18) {

                    // 対象ユーザー
                    VStack(alignment: .leading, spacing: 10) {
                        Text("対象ユーザー")
                            .font(.headline)

                        TextField("対象ユーザーID（顧客UID）", text: $vm.selectedUserId)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)

                        if !vm.selectedUserName.isEmpty {
                            Text("氏名：\(vm.selectedUserName)")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Button("読み込み") {
                                Task { await vm.fetchCoupons() }
                            }
                            .buttonStyle(.bordered)

                            Spacer()

                            Picker("表示", selection: $vm.selectedFilter) {
                                ForEach(CouponManagerVM.Filter.allCases) { f in
                                    Text(f.rawValue).tag(f)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    .padding(.horizontal)

                    Divider().padding(.horizontal)

                    // 発行フォーム
                    VStack(alignment: .leading, spacing: 10) {
                        Text("クーポン発行")
                            .font(.headline)

                        TextField("クーポンタイトル", text: $vm.title)
                            .textFieldStyle(.roundedBorder)

                        TextField("説明文", text: $vm.description)
                            .textFieldStyle(.roundedBorder)

                        DatePicker("有効期限", selection: $vm.validUntil, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .environment(\.locale, Locale(identifier: "ja_JP"))

                        if vm.isCreating {
                            ProgressView("発行中…")
                        } else {
                            Button {
                                Task { await vm.createCoupon() }
                            } label: {
                                Label("クーポンを発行", systemImage: "ticket.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(vm.selectedUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                      || vm.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .padding(.horizontal)

                    // メッセージ類
                    if let err = vm.errorMessage, !err.isEmpty {
                        Text("⚠️ \(err)")
                            .foregroundColor(.red)
                            .font(.footnote)
                            .padding(.horizontal)
                    }

                    if !vm.message.isEmpty {
                        Text(vm.message)
                            .foregroundColor(.secondary)
                            .font(.footnote)
                            .padding(.horizontal)
                    }

                    Divider().padding(.horizontal)

                    // 一覧
                    VStack(alignment: .leading, spacing: 12) {
                        Text("発行済みクーポン一覧")
                            .font(.headline)
                            .padding(.horizontal)

                        if vm.isLoading {
                            ProgressView("読み込み中…")
                                .frame(maxWidth: .infinity)
                        } else if vm.filteredCoupons.isEmpty {
                            Text("該当するクーポンはありません。")
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(vm.filteredCoupons) { coupon in
                                    AdminCouponRow(
                                        coupon: coupon,
                                        onEdit: {
                                            editingCoupon = coupon
                                            showEditSheet = true
                                        },
                                        onToggleUsed: { newUsed in
                                            Task {
                                                do {
                                                    try await vm.setUsed(coupon, to: newUsed)
                                                } catch {
                                                    vm.errorMessage = error.localizedDescription
                                                }
                                            }
                                        },
                                        onDelete: {
                                            deleteTarget = coupon
                                            showDeleteConfirm = true
                                        }
                                    )
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }

                    Spacer(minLength: 16)
                }
                .padding(.top, 14)
            }
            .navigationTitle("クーポン管理")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                // 会員詳細から来た時のプリセット
                if !preselectedUserId.isEmpty {
                    vm.setUser(userId: preselectedUserId, userName: preselectedUserName)
                    await vm.fetchCoupons()
                }
            }
            .sheet(isPresented: $showEditSheet) {
                if let c = editingCoupon {
                    CouponEditSheet(
                        coupon: c,
                        onSave: { newTitle, newDesc, newValidUntil in
                            Task {
                                do {
                                    try await vm.updateCoupon(c, title: newTitle, description: newDesc, validUntil: newValidUntil)
                                    showEditSheet = false
                                } catch {
                                    vm.errorMessage = error.localizedDescription
                                }
                            }
                        },
                        onCancel: { showEditSheet = false }
                    )
                }
            }
            .confirmationDialog("削除しますか？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("削除", role: .destructive) {
                    guard let target = deleteTarget else { return }
                    Task {
                        do {
                            try await vm.deleteCoupon(target)
                        } catch {
                            vm.errorMessage = error.localizedDescription
                        }
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("この操作は取り消せません。")
            }
        }
    }
}

// MARK: - Edit Sheet
private struct CouponEditSheet: View {
    let coupon: CouponManagerVM.AdminCoupon
    let onSave: (String, String, Date) -> Void
    let onCancel: () -> Void

    @State private var title: String
    @State private var desc: String
    @State private var validUntil: Date

    init(
        coupon: CouponManagerVM.AdminCoupon,
        onSave: @escaping (String, String, Date) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.coupon = coupon
        self.onSave = onSave
        self.onCancel = onCancel
        _title = State(initialValue: coupon.title)
        _desc = State(initialValue: coupon.description)
        _validUntil = State(initialValue: coupon.validUntil)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("編集") {
                    TextField("クーポンタイトル", text: $title)
                    TextField("説明文", text: $desc)
                    DatePicker("有効期限", selection: $validUntil, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                }
            }
            .navigationTitle("クーポン編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { onSave(title, desc, validUntil) }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
