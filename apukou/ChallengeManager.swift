//
//  ChallengeManager.swift
//  apukou
//
//  Created by Claude on 2025/08/10.
//

import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct StepChallenge: Identifiable {
    let id = UUID()
    let stepGoal: Int
    let rewardStickers: Int
    let rewardCreationChances: Int
    let title: String
    let description: String
    let isConsecutive: Bool // 連続チャレンジかどうか
    let consecutiveDays: Int // 必要な連続日数
    
    init(stepGoal: Int, rewardStickers: Int, rewardCreationChances: Int, title: String, description: String, isConsecutive: Bool = false, consecutiveDays: Int = 0) {
        self.stepGoal = stepGoal
        self.rewardStickers = rewardStickers
        self.rewardCreationChances = rewardCreationChances
        self.title = title
        self.description = description
        self.isConsecutive = isConsecutive
        self.consecutiveDays = consecutiveDays
    }
    
    static let challenges = [
        StepChallenge(
            stepGoal: 500,
            rewardStickers: 1,
            rewardCreationChances: 1,
            title: "スタートチャレンジ",
            description: "500歩歩いてシール1枚＆作成回数1回をゲット！"
        ),
        StepChallenge(
            stepGoal: 1000,
            rewardStickers: 1,
            rewardCreationChances: 1,
            title: "ファーストステップ",
            description: "1,000歩歩いてシール1枚＆作成回数1回をゲット！"
        ),
        StepChallenge(
            stepGoal: 2000,
            rewardStickers: 1,
            rewardCreationChances: 1,
            title: "ウォーキングチャレンジ",
            description: "2,000歩歩いてシール1枚＆作成回数1回をゲット！"
        ),
        StepChallenge(
            stepGoal: 4000,
            rewardStickers: 1,
            rewardCreationChances: 2,
            title: "アクティブチャレンジ",
            description: "4,000歩歩いてシール1枚＆作成回数2回をゲット！"
        ),
        StepChallenge(
            stepGoal: 6000,
            rewardStickers: 2,
            rewardCreationChances: 2,
            title: "ヘルシーチャレンジ",
            description: "6,000歩歩いてシール2枚＆作成回数2回をゲット！"
        ),
        StepChallenge(
            stepGoal: 8000,
            rewardStickers: 2,
            rewardCreationChances: 3,
            title: "フィットネスチャレンジ",
            description: "8,000歩歩いてシール2枚＆作成回数3回をゲット！"
        ),
        StepChallenge(
            stepGoal: 10000,
            rewardStickers: 3,
            rewardCreationChances: 3,
            title: "マスターチャレンジ",
            description: "10,000歩歩いてシール3枚＆作成回数3回をゲット！"
        ),
        // 連続チャレンジ
        StepChallenge(
            stepGoal: 3000,
            rewardStickers: 2,
            rewardCreationChances: 2,
            title: "3日継続チャレンジ！",
            description: "3日連続で3,000歩達成でシール2枚＆作成回数2回をゲット！",
            isConsecutive: true,
            consecutiveDays: 3
        ),
        StepChallenge(
            stepGoal: 5000,
            rewardStickers: 3,
            rewardCreationChances: 3,
            title: "7日継続チャレンジ！",
            description: "7日連続で5,000歩達成でシール3枚＆作成回数3回をゲット！",
            isConsecutive: true,
            consecutiveDays: 7
        ),
        StepChallenge(
            stepGoal: 4500,
            rewardStickers: 4,
            rewardCreationChances: 4,
            title: "2週間継続チャレンジ！",
            description: "14日連続で4,500歩達成でシール4枚＆作成回数4回をゲット！",
            isConsecutive: true,
            consecutiveDays: 14
        ),
        StepChallenge(
            stepGoal: 4000,
            rewardStickers: 5,
            rewardCreationChances: 5,
            title: "1ヶ月継続チャレンジ！",
            description: "31日連続で4,000歩達成でシール5枚＆作成回数5回をゲット！",
            isConsecutive: true,
            consecutiveDays: 31
        )
    ]
}

class ChallengeManager: ObservableObject {
    static let shared = ChallengeManager()
    
    @Published var completedChallenges: Set<String> = []
    @Published var rewardClaimedChallenges: Set<String> = []
    private let db = Firestore.firestore()
    private var currentUserId: String? {
        return Auth.auth().currentUser?.uid
    }
    
    private init() {
        loadCompletedChallengesFromFirebase()
        loadRewardClaimedChallengesFromFirebase()
    }
    
    private func loadCompletedChallengesFromFirebase() {
        guard let userId = currentUserId else { return }
        
        db.collection("users").document(userId).collection("completedChallenges")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error loading challenges from Firebase: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    self?.completedChallenges = Set(documents.map { $0.documentID })
                    print("📊 Loaded \(documents.count) completed challenges from Firebase")
                }
            }
    }
    
    private func saveCompletedChallengeToFirebase(_ challengeId: String) {
        guard let userId = currentUserId else { return }
        
        let challengeData: [String: Any] = [
            "challengeId": challengeId,
            "completedAt": FieldValue.serverTimestamp(),
            "stepGoal": challengeId.components(separatedBy: "_").first ?? "",
            "date": challengeId.components(separatedBy: "_").last ?? ""
        ]
        
        db.collection("users").document(userId).collection("completedChallenges")
            .document(challengeId).setData(challengeData) { error in
                if let error = error {
                    print("❌ Error saving challenge to Firebase: \(error)")
                } else {
                    print("✅ Challenge saved to Firebase: \(challengeId)")
                }
            }
    }
    
    func checkAndCompleteChallenge(steps: Int, challenge: StepChallenge) -> Bool {
        let challengeId = generateChallengeId(for: challenge)
        print("🔍 チャレンジチェック開始: \(challengeId)")
        print("🔍 現在の歩数: \(steps), 目標歩数: \(challenge.stepGoal)")
        
        // 報酬受け取り済みの場合はfalse（完了はしているが、報酬は受け取れない）
        print("🔍 完了済みチャレンジ一覧: \(completedChallenges)")
        print("🔍 報酬受け取り済み一覧: \(rewardClaimedChallenges)")
        if rewardClaimedChallenges.contains(challengeId) {
            print("🔍 既に報酬受け取り済み: \(challengeId)")
            return false
        }
        
        // 連続チャレンジの場合
        if challenge.isConsecutive {
            print("🔍 連続チャレンジをチェック中...")
            if checkConsecutiveChallenge(challenge: challenge) {
                completedChallenges.insert(challengeId)
                saveCompletedChallengeToFirebase(challengeId)
                print("🎉 Consecutive Challenge completed: \(challenge.title)")
                return true
            } else {
                print("🔍 連続チャレンジ条件未達成")
            }
        } else {
            // 通常チャレンジの場合
            print("🔍 通常チャレンジをチェック中...")
            if steps >= challenge.stepGoal {
                completedChallenges.insert(challengeId)
                saveCompletedChallengeToFirebase(challengeId)
                print("🎉 Challenge completed: \(challenge.title)")
                return true
            } else {
                print("🔍 歩数不足: \(steps) < \(challenge.stepGoal)")
            }
        }
        
        return false
    }
    
    func checkConsecutiveChallenge(challenge: StepChallenge) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        var consecutiveCount = 0
        print("🔍 連続チャレンジチェック: \(challenge.title), 必要日数: \(challenge.consecutiveDays)")
        
        // 過去N日をチェック
        for dayOffset in 0..<challenge.consecutiveDays {
            let checkDate = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
            let dateString = formatter.string(from: checkDate)
            print("🔍 チェック日: \(dateString)")
            
            // その日に該当する歩数チャレンジが達成されているかチェック
            let dayCompleted = completedChallenges.contains { challengeId in
                let components = challengeId.components(separatedBy: "_")
                guard components.count == 2,
                      let stepGoal = Int(components[0]),
                      components[1] == dateString else { return false }
                return stepGoal >= challenge.stepGoal
            }
            
            print("🔍 \(dateString)の達成状況: \(dayCompleted)")
            
            if dayCompleted {
                consecutiveCount += 1
            } else {
                break
            }
        }
        
        print("🔍 連続達成日数: \(consecutiveCount)/\(challenge.consecutiveDays)")
        return consecutiveCount >= challenge.consecutiveDays
    }
    
    func isChallengeCompleted(_ challenge: StepChallenge) -> Bool {
        let challengeId = generateChallengeId(for: challenge)
        return completedChallenges.contains(challengeId)
    }
    
    func isConsecutiveChallengeCompleted(_ challenge: StepChallenge) -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: today)
        let challengeId = "\(challenge.stepGoal)_\(todayString)_consecutive_\(challenge.consecutiveDays)"
        return completedChallenges.contains(challengeId)
    }
    
    func generateChallengeId(for challenge: StepChallenge) -> String {
        let today = Calendar.current.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: today)
        
        if challenge.isConsecutive {
            return "\(challenge.stepGoal)_\(dateString)_consecutive_\(challenge.consecutiveDays)"
        } else {
            return "\(challenge.stepGoal)_\(dateString)"
        }
    }
    
    func getAvailableChallenges(currentSteps: Int) -> [StepChallenge] {
        return StepChallenge.challenges.filter { challenge in
            let challengeId = generateChallengeId(for: challenge)
            
            // 報酬受け取り済みの場合は除外
            return !rewardClaimedChallenges.contains(challengeId)
        }
    }
    
    func markRewardClaimed(for challenge: StepChallenge) {
        let challengeId = generateChallengeId(for: challenge)
        rewardClaimedChallenges.insert(challengeId)
        saveRewardClaimedToFirebase(challengeId)
        print("✅ 報酬受け取り完了: \(challengeId)")
    }
    
    private func loadRewardClaimedChallengesFromFirebase() {
        guard let userId = currentUserId else { return }
        
        db.collection("users").document(userId).collection("rewardClaimed")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error loading reward claimed from Firebase: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    self?.rewardClaimedChallenges = Set(documents.map { $0.documentID })
                    print("📊 Loaded \(documents.count) reward claimed challenges from Firebase")
                }
            }
    }
    
    private func saveRewardClaimedToFirebase(_ challengeId: String) {
        guard let userId = currentUserId else { return }
        
        let rewardData: [String: Any] = [
            "challengeId": challengeId,
            "claimedAt": FieldValue.serverTimestamp()
        ]
        
        db.collection("users").document(userId).collection("rewardClaimed")
            .document(challengeId).setData(rewardData) { error in
                if let error = error {
                    print("❌ Error saving reward claimed to Firebase: \(error)")
                } else {
                    print("✅ Reward claimed saved to Firebase: \(challengeId)")
                }
            }
    }
    
    func resetDailyChallenges() {
        // 日付が変わった時のリセット処理（必要に応じて実装）
        // 現在は1日1回のチャレンジなので、日付ベースのIDで管理
    }
    
    func resetUserData() {
        DispatchQueue.main.async {
            self.completedChallenges = []
            self.rewardClaimedChallenges = []
            print("✅ ChallengeManager データをリセットしました")
        }
    }
    
    // 全期間での達成チャレンジ数を計算（レベル計算用）
    func getTotalCompletedChallenges() -> Int {
        // 全ての完了済みチャレンジIDを取得
        let allCompletedChallenges = Set(completedChallenges.compactMap { challengeId in
            // 日付部分を除いて、チャレンジの種類だけを取得
            challengeId.components(separatedBy: "_").first
        })
        return allCompletedChallenges.count
    }
    
    // 今日達成したチャレンジ数を計算
    func getTodayCompletedChallengesCount() -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: today)
        
        return completedChallenges.filter { $0.contains(dateString) }.count
    }
    
    // チャレンジ履歴を取得（最近N日分）
    func getChallengeHistory(days: Int = 30) async -> [(date: String, challenges: [String])] {
        guard let userId = currentUserId else { return [] }
        
        var history: [(date: String, challenges: [String])] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        do {
            let snapshot = try await db.collection("users").document(userId)
                .collection("completedChallenges")
                .order(by: "completedAt", descending: true)
                .limit(to: days * 5) // 1日最大5チャレンジ
                .getDocuments()
            
            var challengesByDate: [String: [String]] = [:]
            
            for document in snapshot.documents {
                let data = document.data()
                if let date = data["date"] as? String,
                   let stepGoal = data["stepGoal"] as? String {
                    challengesByDate[date, default: []].append(stepGoal)
                }
            }
            
            history = challengesByDate.map { (date: $0.key, challenges: $0.value) }
                .sorted { $0.date > $1.date }
            
        } catch {
            print("❌ Error fetching challenge history: \(error)")
        }
        
        return history
    }
}
