import SwiftUI
import ShapeCore
import Photos

struct PostureMultiAnalysisView: View {

    let shots: [CapturedShot]
    let onRetakeAll: () -> Void
    let onClose: () -> Void

    @StateObject private var vm: PostureMultiAnalysisVM

    // Export
    @State private var isExporting: Bool = false
    @State private var exportedImage: UIImage? = nil

    // Share / Save
    @State private var showShare: Bool = false
    @State private var showExportError: Bool = false
    @State private var exportErrorMessage: String = ""

    @State private var showExportOptions: Bool = false

    // Save alert
    @State private var showSaveAlert: Bool = false
    @State private var saveAlertTitle: String = ""
    @State private var saveAlertMessage: String = ""
    @State private var showOpenSettingsButton: Bool = false

    @Environment(\.openURL) private var openURL

    init(
        shots: [CapturedShot],
        onRetakeAll: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.shots = shots
        self.onRetakeAll = onRetakeAll
        self.onClose = onClose
        _vm = StateObject(wrappedValue: PostureMultiAnalysisVM(shots: shots))
    }

    var body: some View {
        ZStack {
            Theme.gradientMain.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {

                    sheetNavHeader

                    sheetIntroCard

                    if vm.isLoading {
                        loadingBar
                            .padding(.horizontal, 18)
                    }

                    // 4方向：縦に並べる（シートっぽく）
                    VStack(spacing: 14) {
                        ForEach(vm.items) { item in
                            directionRow(item)
                        }
                    }
                    .padding(.horizontal, 18)

                    summaryCard
                        .padding(.horizontal, 18)
                        .padding(.top, 2)

                    bottomActions
                        .padding(.horizontal, 18)
                        .padding(.top, 6)
                        .padding(.bottom, 24)
                }
                .padding(.top, 10)
            }

            // Export overlay
            if isExporting {
                Color.black.opacity(0.25).ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                    Text("レポートを書き出しています…")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                }
                .padding(18)
                .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .onAppear { vm.start() }
        .interactiveDismissDisabled(true)
        .navigationBarBackButtonHidden(true)

        // 共有シート
        .sheet(isPresented: $showShare) {
            if let img = exportedImage {
                ShareSheet(items: [img])
            } else {
                ShareSheet(items: [])
            }
        }

        // 書き出しエラー
        .alert("書き出しに失敗しました", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage)
        }

        // 書き出し後の選択（共有 or 写真に保存）
        .confirmationDialog(
            "レポートの出力",
            isPresented: $showExportOptions,
            titleVisibility: .visible
        ) {
            Button("共有する（AirDrop / LINE など）") {
                showShare = true
            }

            Button("写真に保存する") {
                saveExportedImageToPhotos()
            }

            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("出力したレポートをどうしますか？")
        }

        // 写真保存の結果アラート
        .alert(saveAlertTitle, isPresented: $showSaveAlert) {
            if showOpenSettingsButton {
                Button("設定を開く") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveAlertMessage)
        }
    }
}

// MARK: - Top Nav (撮影に戻る / 閉じる / タイトル)
private extension PostureMultiAnalysisView {

    var sheetNavHeader: some View {
        VStack(spacing: 10) {

            HStack {
                Button {
                    // 「戻れない・固まる」対策：ここは強制的に撮影に戻す
                    onRetakeAll()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("撮影に戻る")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Theme.dark.opacity(0.85))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color.white.opacity(0.70), in: Capsule())
                }

                Spacer()

                Button { onClose() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Theme.dark.opacity(0.75))
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.70), in: Circle())
                }
            }
            .padding(.horizontal, 18)

            HStack {
                Spacer()
                Text("姿勢分析シート")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(Theme.dark.opacity(0.88))
                Spacer()
            }
            .padding(.horizontal, 18)

            HStack {
                Spacer()
                Text("撮影日：\(Self.dateString())")
                    .font(.caption)
                    .foregroundColor(Theme.dark.opacity(0.60))
                    .padding(.horizontal, 18)
            }
        }
    }

    static func dateString() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy/MM/dd"
        return f.string(from: Date())
    }
}

// MARK: - Intro
private extension PostureMultiAnalysisView {

    var sheetIntroCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("姿勢分析シート")
                .font(.title3.weight(.semibold))
                .foregroundColor(Theme.dark.opacity(0.88))

            Text("4方向（正面・右・背面・左）を解析して総合評価を表示します。")
                .font(.subheadline)
                .foregroundColor(Theme.dark.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.92))
                .shadow(color: Theme.dark.opacity(0.08), radius: 10, y: 6)
        )
        .padding(.horizontal, 18)
    }
}

// MARK: - Loading
private extension PostureMultiAnalysisView {

    var loadingBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView()
            Text(vm.progressText.isEmpty ? "解析中…" : vm.progressText)
                .font(.footnote)
                .foregroundColor(Theme.dark.opacity(0.65))
        }
    }
}

// MARK: - Direction Row (左：画像 / 右：スコア&文章)
private extension PostureMultiAnalysisView {

    func directionRow(_ item: PostureMultiAnalysisVM.Item) -> some View {
        HStack(spacing: 14) {

            Image(uiImage: item.skeletonImage ?? item.original)
                .resizable()
                .scaledToFill()
                .frame(width: 130, height: 170)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 10) {

                HStack(spacing: 10) {
                    pill(item.direction.title, fg: .white, bg: Color.black.opacity(0.35))

                    if let score = item.score {
                        pill("\(score)", fg: .white, bg: Theme.sub.opacity(0.88))
                    } else if item.errorText != nil {
                        pill("ERR", fg: .white, bg: Color.red.opacity(0.75))
                    } else {
                        pill("…", fg: .white, bg: Color.black.opacity(0.25))
                    }

                    Spacer()
                }

                Group {
                    if let _ = item.score {
                        Text("点数")
                            .font(.caption)
                            .foregroundColor(Theme.dark.opacity(0.60))

                        Text("\(item.direction.title)の写真のレビューと考察")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Theme.dark.opacity(0.86))

                        if let msg = item.message, !msg.isEmpty {
                            Text(msg)
                                .font(.subheadline)
                                .foregroundColor(Theme.dark.opacity(0.70))
                                .lineLimit(3)
                        } else {
                            Text("解析結果を作成しています…")
                                .font(.subheadline)
                                .foregroundColor(Theme.dark.opacity(0.60))
                        }
                    } else if let err = item.errorText {
                        Text("解析に失敗しました")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.red.opacity(0.85))

                        Text(err)
                            .font(.subheadline)
                            .foregroundColor(.red.opacity(0.70))
                            .lineLimit(3)
                    } else {
                        Text("解析中…")
                            .font(.subheadline)
                            .foregroundColor(Theme.dark.opacity(0.60))
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.92))
                .shadow(color: Theme.dark.opacity(0.08), radius: 10, y: 6)
        )
    }

    func pill(_ text: String, fg: Color, bg: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(fg)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(bg, in: Capsule())
    }
}

// MARK: - Summary
private extension PostureMultiAnalysisView {

    var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack {
                Text("総合評価")
                    .font(.headline)
                    .foregroundColor(Theme.dark.opacity(0.88))

                Spacer()

                if let s = vm.summaryScore {
                    pill("\(s) / 100", fg: .white, bg: Theme.sub.opacity(0.88))
                } else {
                    pill("解析中", fg: .white, bg: Color.black.opacity(0.25))
                }
            }

            scoreScaleBar(score: vm.summaryScore)

            VStack(alignment: .leading, spacing: 6) {
                Text(vm.summaryHeadline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Theme.dark.opacity(0.86))

                Text(vm.summaryMessage.isEmpty ? "解析結果をまとめています…" : vm.summaryMessage)
                    .font(.subheadline)
                    .foregroundColor(Theme.dark.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)

                if !vm.summaryBullets.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(vm.summaryBullets, id: \.self) { b in
                            Text("・\(b)")
                                .font(.footnote)
                                .foregroundColor(Theme.dark.opacity(0.68))
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.92))
                .shadow(color: Theme.dark.opacity(0.10), radius: 10, y: 6)
        )
    }

    func scoreScaleBar(score: Int?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.08))
                        .frame(height: 10)

                    if let s = score {
                        let clamped = min(max(s, 0), 100)
                        let w = geo.size.width * CGFloat(clamped) / 100.0

                        Capsule()
                            .fill(Theme.sub.opacity(0.85))
                            .frame(width: w, height: 10)

                        Circle()
                            .fill(Color.white)
                            .overlay(Circle().stroke(Color.black.opacity(0.15), lineWidth: 1))
                            .frame(width: 16, height: 16)
                            .offset(x: max(0, min(geo.size.width - 16, w - 8)))
                    }
                }
            }
            .frame(height: 16)

            HStack {
                Text("〜59")
                Spacer()
                Text("〜69")
                Spacer()
                Text("〜79")
                Spacer()
                Text("〜89")
                Spacer()
                Text("〜100")
            }
            .font(.caption2)
            .foregroundColor(Theme.dark.opacity(0.55))
        }
    }
}

// MARK: - Bottom actions（書き出し＋写真保存）
private extension PostureMultiAnalysisView {

    var bottomActions: some View {
        VStack(spacing: 12) {

            GlassButton(
                title: isExporting ? "書き出し中…" : "レポートを書き出す",
                systemImage: "square.and.arrow.up",
                background: Theme.sub
            ) {
                exportReport(showOptionsAfterExport: true)
            }
            .disabled(isExporting || vm.isLoading)

            GlassButton(
                title: isExporting ? "保存準備中…" : "写真に保存",
                systemImage: "photo.on.rectangle",
                background: Theme.sub.opacity(0.85)
            ) {
                // 画像が無ければ生成してから保存
                if exportedImage == nil {
                    exportReport(showOptionsAfterExport: false, saveToPhotosAfterExport: true)
                } else {
                    saveExportedImageToPhotos()
                }
            }
            .disabled(isExporting || vm.isLoading)

            GlassButton(
                title: "撮影開始画面に戻る",
                systemImage: "chevron.left",
                background: Theme.dark.opacity(0.30)
            ) { onRetakeAll() }
            .disabled(isExporting)

            GlassButton(
                title: "閉じる",
                systemImage: "xmark",
                background: Theme.dark.opacity(0.35)
            ) { onClose() }
            .disabled(isExporting)
        }
    }

    func exportReport(showOptionsAfterExport: Bool = true, saveToPhotosAfterExport: Bool = false) {
        guard !isExporting else { return }

        guard !vm.items.isEmpty else {
            exportErrorMessage = "レポートの内容がまだ準備できていません。"
            showExportError = true
            return
        }

        isExporting = true

        let reportView = PostureReportRenderView(
            title: "姿勢分析シート",
            dateText: Self.dateString(),
            items: vm.items,
            summaryScoreText: (vm.summaryScore != nil) ? "\(vm.summaryScore!) / 100" : "解析中",
            summaryHeadline: vm.summaryHeadline,
            summaryMessage: vm.summaryMessage.isEmpty ? "解析結果をまとめています…" : vm.summaryMessage,
            summaryBullets: vm.summaryBullets
        )

        Task { @MainActor in
            let renderer = ImageRenderer(content: reportView)
            renderer.scale = 2
            renderer.isOpaque = true

            if let uiImage = renderer.uiImage {
                self.exportedImage = uiImage
                self.isExporting = false

                if saveToPhotosAfterExport {
                    saveExportedImageToPhotos()
                    return
                }

                if showOptionsAfterExport {
                    self.showExportOptions = true
                } else {
                    // オプションを出さない場合は共有へ
                    self.showShare = true
                }

            } else {
                self.isExporting = false
                self.exportErrorMessage = "画像の生成に失敗しました。"
                self.showExportError = true
            }
        }
    }

    func saveExportedImageToPhotos() {
        guard let img = exportedImage else {
            saveAlertTitle = "保存できません"
            saveAlertMessage = "保存する画像がありません。先にレポートを書き出してください。"
            showOpenSettingsButton = false
            showSaveAlert = true
            return
        }

        PhotoSaver.save(img) { result in
            switch result {
            case .success:
                saveAlertTitle = "保存しました"
                saveAlertMessage = "写真フォルダに保存しました。"
                showOpenSettingsButton = false

            case .denied:
                saveAlertTitle = "許可が必要です"
                saveAlertMessage = "写真への追加が許可されていません。設定アプリで「写真」→「追加のみ」を許可してください。"
                showOpenSettingsButton = true

            case .failure(let error):
                saveAlertTitle = "保存に失敗しました"
                saveAlertMessage = error.localizedDescription
                showOpenSettingsButton = false
            }

            showSaveAlert = true
        }
    }
}
