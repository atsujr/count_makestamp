//
//  ChallengeCardView.swift
//  apukou
//
//  Created by Claude on 2025/08/10.
//

import SwiftUI

struct ChallengeCardView: View {
    let challenge: StepChallenge
    let currentSteps: Int
    let isCompleted: Bool
    let onReward: (Int, Int) -> Void
    
    @StateObject private var challengeManager = ChallengeManager.shared
    
    private let darkPink = Color(red: 245/255, green: 114/255, blue: 182/255) //#F572B6
    private let darkBlue = Color(red: 37/255, green: 162/255, blue: 220/255) //#25A2DC
    private let darkPurple = Color(red: 211/255, green: 123/255, blue: 255/255)//#D37BFF
    private let mainPink = Color(red: 255/255, green: 202/255, blue: 227/255) //#FFCAE3
    
    private var progress: Double {
        return min(Double(currentSteps) / Double(challenge.stepGoal), 1.0)
    }
    
    private var isAchieved: Bool {
        if challenge.isConsecutive {
            // 連続チャレンジの場合は、今日の歩数チェックのみ（連続性は報酬時にチェック）
            return currentSteps >= challenge.stepGoal
        } else {
            return currentSteps >= challenge.stepGoal
        }
    }
    
    private var isRewardClaimed: Bool {
        let challengeId = challengeManager.generateChallengeId(for: challenge)
        return challengeManager.rewardClaimedChallenges.contains(challengeId)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // チャレンジタイトルと報酬
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.title)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text(challenge.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "seal")
                                .foregroundColor(.orange)
                            Text("×\(challenge.rewardStickers)")
                                .fontWeight(.semibold)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.blue)
                            Text("×\(challenge.rewardCreationChances)")
                                .fontWeight(.semibold)
                        }
                    }
                    .font(.subheadline)
                    
                    if isRewardClaimed {
                        Text("達成済み")
                            .font(.caption)
                            .foregroundColor(darkPink)
                            .fontWeight(.medium)
                    } else if isAchieved {
                        Text("達成！")
                            .font(.caption)
                            .foregroundColor(darkPurple)
                            .fontWeight(.medium)
                    }
                }
            }
            
            // 進捗バー
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(currentSteps) / \(challenge.stepGoal) 歩")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(progress >= 1.0 ? darkPink : .secondary)
                }
                
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: progress >= 1.0 ? darkPink : darkPurple))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
            }
            
            // 報酬ボタン
            if isAchieved && !isRewardClaimed {
                Button(action: {
                    onReward(challenge.rewardStickers, challenge.rewardCreationChances)
                }) {
                    HStack {
                        Image(systemName: "gift")
                        Text("報酬を受け取る")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(darkPurple)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            } else if isCompleted {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(darkPink)
                    Text("達成済み")
                        .fontWeight(.semibold)
                        .foregroundColor(darkPink)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(mainPink.opacity(0.2))
                .cornerRadius(12)
            } else {
                HStack {
                    Image(systemName: "figure.walk")
                        .foregroundColor(.gray)
                    Text("歩数が足りません")
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isCompleted ? Color.white.opacity(0.3) : (isAchieved ? darkPurple.opacity(0.3) : Color.clear), lineWidth: 2)
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        ChallengeCardView(
            challenge: StepChallenge.challenges[0],
            currentSteps: 500,
            isCompleted: false,
            onReward: { _, _ in }
        )
        
        ChallengeCardView(
            challenge: StepChallenge.challenges[1],
            currentSteps: 3500,
            isCompleted: false,
            onReward: { _, _ in }
        )
        
        ChallengeCardView(
            challenge: StepChallenge.challenges[2],
            currentSteps: 5000,
            isCompleted: true,
            onReward: { _, _ in }
        )
    }
    .padding()
}
