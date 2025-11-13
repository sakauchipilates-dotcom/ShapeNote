import SwiftUI
import ShapeCore

struct AdminMemberListView: View {
    @StateObject private var vm = AdminUserListVM()
    @State private var showAdvancedFilter = false // 詳細検索開閉
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 検索バー
                searchSection
                
                // 詳細検索トグル
                Button {
                    withAnimation(.easeInOut) {
                        showAdvancedFilter.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text(showAdvancedFilter ? "詳細検索を閉じる" : "詳細検索")
                        Spacer()
                        Image(systemName: showAdvancedFilter ? "chevron.up" : "chevron.down")
                            .font(.subheadline)
                    }
                    .font(.subheadline)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                .padding(.top, 6)
                
                // 詳細検索エリア
                if showAdvancedFilter {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            filterSection(title: "性別", items: UserItem.Gender.allCases.map { $0.label }) { label in
                                vm.toggleGender(label: label)
                            } isSelected: { label in
                                vm.isGenderSelected(label: label)
                            }
                            
                            filterSection(title: "年代", items: stride(from: 10, through: 80, by: 10).map { "\($0)代" }) { label in
                                vm.toggleDecade(label: label)
                            } isSelected: { label in
                                vm.isDecadeSelected(label: label)
                            }
                            
                            filterSection(title: "ランク", items: ["レギュラー", "ブロンズ", "シルバー", "ゴールド", "プラチナ"]) { label in
                                vm.toggleRank(label: label)
                            } isSelected: { label in
                                vm.isRankSelected(label: label)
                            }
                            
                            HStack {
                                Spacer()
                                Button {
                                    vm.resetFilters()
                                } label: {
                                    Label("条件をリセット", systemImage: "arrow.uturn.left")
                                        .font(.footnote)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 12)
                                        .background(Color(.systemGray5))
                                        .cornerRadius(8)
                                }
                                Spacer()
                            }
                            .padding(.top, 8)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                    }
                    .background(Color(.systemGray6).opacity(0.2))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Divider().padding(.top, 4)
                
                // 一覧表示
                List {
                    ForEach(vm.filteredUsers) { user in
                        NavigationLink(destination: AdminMemberDetailView(user: user)) {
                            memberRow(for: user)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("会員管理")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - 検索バー
    private var searchSection: some View {
        VStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("名前・メールで検索", text: $vm.searchText)
                    .textFieldStyle(.plain)
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
        }
        .padding(.top, 8)
    }
    
    // MARK: - チェックボックス群
    private func filterSection(
        title: String,
        items: [String],
        action: @escaping (String) -> Void,
        isSelected: @escaping (String) -> Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.bold())
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
                ForEach(items, id: \.self) { label in
                    Button {
                        action(label)
                    } label: {
                        HStack {
                            Image(systemName: isSelected(label) ? "checkmark.square.fill" : "square")
                                .foregroundColor(isSelected(label) ? .accentColor : .secondary)
                            Text(label)
                                .font(.footnote)
                                .foregroundColor(.primary)
                            Spacer(minLength: 0)
                        }
                        .padding(6)
                        .background(Color(.systemBackground))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSelected(label) ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - メンバー行UI
    private func memberRow(for user: UserItem) -> some View {
        HStack(spacing: 12) {
            avatar(urlString: user.iconURL)
            VStack(alignment: .leading, spacing: 4) {
                Text(user.name).font(.headline)
                Text(user.email).font(.caption).foregroundColor(.secondary)
                HStack(spacing: 6) {
                    pill(text: user.gender.label, color: user.gender == .male ? .blue : (user.gender == .female ? .pink : .gray))
                    if let by = user.birthYear {
                        let decade = AdminUserListVM.decadeFromBirthYear(by)
                        pill(text: "\(decade)代", color: .teal)
                    }
                    if let rank = user.membershipRank {
                        let c: Color = switch rank {
                        case .regular: .mint
                        case .bronze: .brown
                        case .silver: .gray
                        case .gold: .yellow
                        case .platinum: .cyan
                        }
                        pill(text: rank.label, color: c)
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(Color(UIColor.tertiaryLabel)) // ✅ 修正ポイント！
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Avatar
    private func avatar(urlString: String?) -> some View {
        Group {
            if let s = urlString, let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    case .empty: ProgressView()
                    default: Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFill()
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFill()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
    }
    
    // MARK: - Pill（小タグ）
    private func pill(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(color.opacity(0.18))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}
