//
//  StickerAcquisitionView.swift
//  apukou
//
//  Created by Claude on 2025/08/10.
//

import SwiftUI


struct StickerAcquisitionView: View {
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var challengeManager = ChallengeManager.shared
    @StateObject private var dataManager = StickerDataManager.shared
    
    @State private var showingRewardAlert = false
    @State private var rewardMessage = ""
    @State private var rewardTitle = "チャレンジ達成！"
    @State private var showingPermissionAlert = false
    
    private let mainPink = Color(red: 255/255, green: 202/255, blue: 227/255) //#FFCAE3
    private let mainBlue = Color(red: 162/255, green: 242/255, blue: 251/255) //#A2F2FB
    private let darkPink = Color(red: 245/255, green: 114/255, blue: 182/255) //#F572B6
    private let darkBlue = Color(red: 37/255, green: 162/255, blue: 220/255) //#25A2DC
    private let darkPurple = Color(red: 211/255, green: 123/255, blue: 255/255)//#D37BFF
    
    private var profileBackgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [mainPink, mainBlue]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 24) {
                    // ヘッダー
                    VStack(spacing: 10) {
                        HStack(alignment: .center) {
                            Spacer()
                            Spacer()
                            Spacer()
                            Spacer()
                            Spacer()
                            Spacer()
                            
                            // レベルバッジ
                            VStack(spacing: 3) {
                                Text("レベル")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("\(calculateUserLevel())")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            .frame(width: 60, height: 60)
                            .background(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                               darkPurple, darkPink]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .shadow(color: Color.purple.opacity(0.3), radius: 4, x: 0, y: 2)
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        Image(systemName: "figure.walk")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text("歩数チャレンジ")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("歩いてシールをゲット&作成しよう！")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 10)
                    
                    
                    // ヘルスケア権限が無い場合の説明
                    if !healthKitManager.isAuthorized {
                        VStack(spacing: 16) {
                            Image(systemName: "heart.text.square")
                                .font(.system(size: 40))
                                .foregroundColor(.red)
                            
                            Text("ヘルスケアとの連携が必要です")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Text("歩数チャレンジを開始するために、ヘルスケアアプリの歩数データへのアクセス権限が必要です。")
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("設定手順：")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("1.")
                                            .fontWeight(.bold)
                                        Text("下の「ヘルスケア権限を許可」ボタンをタップ")
                                    }
                                    HStack {
                                        Text("2.")
                                            .fontWeight(.bold)
                                        Text("表示されるダイアログで「許可」をタップ")
                                    }
                                    HStack {
                                        Text("3.")
                                            .fontWeight(.bold)
                                        Text("ヘルスケアアプリが開いたら「歩数」をオンにする")
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                            
                            Button(action: {
                                print("🔵 ヘルスケア権限許可ボタンがタップされました")
                                Task {
                                    await healthKitManager.requestAuthorization()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "heart.fill")
                                    Text("ヘルスケア権限を許可")
                                        .fontWeight(.semibold)
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(darkPink)
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(radius: 4)
                        .padding(.horizontal)
                        
                        Spacer()
                        
                    } else {
                        // 今日の歩数表示 - 円形プログレスバー
                        VStack(spacing: 16) {
                            Text("今日の歩数")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            ZStack {
                                // 背景の円
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 18)
                                    .frame(width: 150, height: 150)
                                
                                // プログレス円（10,000歩を目標とする）
                                Circle()
                                    .trim(from: 0, to: min(Double(healthKitManager.dailySteps) / 10000.0, 1.0))
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [darkPurple, darkPink]),
                                            startPoint: .topTrailing,
                                            endPoint: .bottomLeading
                                        ),
                                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                                    )
                                    .frame(width: 150, height: 150)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.spring(response: 1.0, dampingFraction: 0.8), value: healthKitManager.dailySteps)
                                
                                // 中央の歩数表示
                                VStack(spacing: 4) {
                                    Text("\(healthKitManager.dailySteps)")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                    
                                    Text("歩")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Text("\(Int(min(Double(healthKitManager.dailySteps) / 10000.0 * 100, 100)))%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(radius: 4)
                        .padding(.horizontal)
                        
                        // チャレンジリスト
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("チャレンジ一覧")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Spacer()
                                NavigationLink(destination: CompletedChallengesView()) {
                                    Text("達成済み")
                                        .foregroundColor(.blue)
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal)
                            
                            LazyVStack(spacing: 12) {
                                ForEach(challengeManager.getAvailableChallenges(currentSteps: healthKitManager.dailySteps)) { challenge in
                                    ChallengeCardView(
                                        challenge: challenge,
                                        currentSteps: healthKitManager.dailySteps,
                                        isCompleted: challengeManager.isChallengeCompleted(challenge),
                                        onReward: { rewardStickers, rewardChances in
                                            Task {
                                                await claimReward(for: challenge, stickers: rewardStickers, creationChances: rewardChances)
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
            }
            .background(profileBackgroundGradient)
//            .navigationTitle("歩数チャレンジ")
//            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await healthKitManager.fetchTodaySteps()
            }
        }
        .onAppear {
            setupHealthKit()
        }
        .task {
            healthKitManager.checkAuthorizationStatus()
        }
        .alert("ヘルスケア権限の設定", isPresented: $showingPermissionAlert) {
            Button("設定手順を確認") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("再試行") {
                Task {
                    await healthKitManager.requestAuthorization()
                }
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("歩数チャレンジを利用するには、ヘルスケアアプリでapukouに歩数の読み取り権限を与える必要があります。\n\n設定 > プライバシーとセキュリティ > ヘルスケア > apukou > 歩数データをオンにしてください。")
        }
        .alert(rewardTitle, isPresented: $showingRewardAlert) {
            Button("確認") { }
        } message: {
            Text(rewardMessage)
        }
        .preferredColorScheme(.light)
    }
    
    
    private func setupHealthKit() {
        if !healthKitManager.isHealthKitAvailable {
            print("❌ HealthKit not available")
            return
        }
        
        if healthKitManager.isAuthorized {
            Task {
                await healthKitManager.fetchTodaySteps()
            }
            healthKitManager.enableBackgroundUpdates()
        }
    }
    
    private func claimReward(for challenge: StepChallenge, stickers: Int, creationChances: Int) async {
        print("🎁 報酬受け取り開始: \(challenge.title)")
        print("🎁 現在の歩数: \(healthKitManager.dailySteps), 必要歩数: \(challenge.stepGoal)")
        
        let completed = challengeManager.checkAndCompleteChallenge(steps: healthKitManager.dailySteps, challenge: challenge)
        print("🎁 チャレンジ完了チェック結果: \(completed)")
        
        if completed {
            print("🎁 報酬付与開始")
            // 実際にシールを付与する処理
            for _ in 0..<stickers {
                // ランダムなシール画像を生成（仮実装）
                if let rewardImage = generateRandomStickerImage() {
                    dataManager.addReceivedSticker(image: rewardImage, challengeTitle: challenge.title)
                }
            }
            
            // 作成チャンスを付与する処理
            await dataManager.addCreationChances(creationChances)
            
            // 報酬受け取り完了をマーク
            challengeManager.markRewardClaimed(for: challenge)
            
            rewardTitle = "\(challenge.title)達成！"
            rewardMessage = "\nシール\(stickers)枚 ＆ 作成チャンス\(creationChances)回をゲット!"
            print("🎁 アラート表示準備完了")
            showingRewardAlert = true
        } else {
            print("🎁 チャレンジ未完了のため報酬なし")
        }
    }
    
    private func generateRandomStickerImage() -> UIImage? {
        let size = CGSize(width: 200, height: 200)
        let baseColors: [UIColor] = [.systemRed, .systemBlue, .systemGreen, .systemOrange, .systemPurple, .systemPink]
        
        guard let baseColor = baseColors.randomElement() else { return nil }
        
        let highlightColor = UIColor.white.withAlphaComponent(0.8)
        
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let cgContext = context.cgContext
            let rect = CGRect(origin: .zero, size: size)
            
            // 円形パスでクリップ
            let circlePath = UIBezierPath(ovalIn: rect)
            cgContext.addPath(circlePath.cgPath)
            cgContext.clip()
            
            // ---- ベースの放射状グラデーション ----
            let gradientColors = [highlightColor.cgColor, baseColor.cgColor] as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace,
                                      colors: gradientColors,
                                      locations: [0.0, 1.0])!
            
            cgContext.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: size.width/2, y: size.height/2),
                startRadius: 0,
                endCenter: CGPoint(x: size.width/2, y: size.height/2),
                endRadius: size.width/2,
                options: []
            )
            
           // ---- 内側シャドウ風の縁取り（濃いベース色を薄く描く）----
            cgContext.setStrokeColor(baseColor.withAlphaComponent(0.4).cgColor)
            cgContext.setLineWidth(6)
            cgContext.strokeEllipse(in: rect.insetBy(dx: 3, dy: 3))
        }
    }

    
    private func calculateUserLevel() -> Int {
        // 達成チャレンジ数でレベルを計算
        let completedChallenges = challengeManager.getTotalCompletedChallenges()
        return max(1, completedChallenges + 1) // 最低レベル1、チャレンジ達成数+1
    }
}

import SwiftUI

struct CompletedChallengesView: View {
    @StateObject private var challengeManager = ChallengeManager.shared
    @Environment(\.dismiss) private var dismiss
    
    private let mainBlue = Color(red: 162/255, green: 242/255, blue: 251/255) //#A2F2FB
    
    // 背景グラデーション
    private var backgroundGradient: some View {
        RadialGradient(
            gradient: Gradient(colors: [mainBlue, Color.white]),
            center: .center,
            startRadius: 50,
            endRadius: 400
        )
        .ignoresSafeArea()
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                
                ScrollView {
                    VStack(spacing: 16) {
                        if challengeManager.completedChallenges.isEmpty {
                            emptyStateView
                                .padding(.top, 50)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(getCompletedChallengesWithDates(), id: \.challengeId) { completedChallenge in
                                    CompletedChallengeCardView(
                                        challenge: completedChallenge.challenge,
                                        completedDate: completedChallenge.date
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("達成済みチャレンジ")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.light)
        }
    }
    
    // 空状態ビュー
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("まだチャレンジを達成していません")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("歩数チャレンジを達成してここに記録を残そう！")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // 完了チャレンジを取得
    private func getCompletedChallengesWithDates() -> [(challengeId: String, challenge: StepChallenge, date: String)] {
        return challengeManager.completedChallenges.compactMap { challengeId in
            let components = challengeId.components(separatedBy: "_")
            guard components.count == 2,
                  let stepGoal = Int(components[0]),
                  let challenge = StepChallenge.challenges.first(where: { $0.stepGoal == stepGoal }) else {
                return nil
            }
            
            let dateString = components[1]
            return (challengeId: challengeId, challenge: challenge, date: dateString)
        }.sorted { $0.date > $1.date }
    }
}

// 完了チャレンジカード
struct CompletedChallengeCardView: View {
    let challenge: StepChallenge
    let completedDate: String
    
    private let darkPink = Color(red: 245/255, green: 114/255, blue: 182/255) //#F572B6
    private let darkBlue = Color(red: 37/255, green: 162/255, blue: 220/255) //#25A2DC
    private let darkPurple = Color(red: 211/255, green: 123/255, blue: 255/255)//#D37BFF
    
    var body: some View {
        HStack(spacing: 16) {
            // チャレンジアイコン
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [darkPurple, darkPink]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(challenge.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("\(challenge.stepGoal)歩達成")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("達成日: \(formatDate(completedDate))")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("報酬")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text("\(challenge.rewardStickers)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    HStack(spacing: 2) {
                        Image(systemName: "plus.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text("\(challenge.rewardCreationChances)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let date = formatter.date(from: dateString) {
            formatter.dateStyle = .medium
            formatter.locale = Locale(identifier: "ja_JP")
            return formatter.string(from: date)
        }
        
        return dateString
    }
}

// プレビュー
#Preview {
    CompletedChallengesView()
}
