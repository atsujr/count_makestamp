//
//  HealthKitManager.swift
//  apukou
//
//  Created by Claude on 2025/08/10.
//

import Foundation
import HealthKit
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    @Published var dailySteps: Int = 0
    @Published var isAuthorized: Bool = false
    @Published var isHealthKitAvailable: Bool = false
    
    private let db = Firestore.firestore()
    private var currentUserId: String? {
        return Auth.auth().currentUser?.uid
    }
    
    private init() {
        isHealthKitAvailable = HKHealthStore.isHealthDataAvailable()
        loadDailyStepsFromFirebase()
    }
    
    // MARK: - Authorization
    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit is not available on this device")
            await MainActor.run {
                self.isAuthorized = false
            }
            return
        }
        
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let readTypes: Set<HKObjectType> = [stepType]
        
        do {
            // 強制的に認証ダイアログを表示
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            
            // 認証状態を実際のデータアクセスで確認
            print("🔄 Checking authorization by attempting data access...")
            
            // 少し待ってから認証状態をチェック
            try await Task.sleep(for: .seconds(1))
            checkAuthorizationStatus()
            
        } catch {
            print("❌ HealthKit authorization failed: \(error)")
            await MainActor.run {
                self.isAuthorized = false
            }
        }
    }
    
    // 認証状態をチェック
    func checkAuthorizationStatus() {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let authStatus = healthStore.authorizationStatus(for: stepType)
        
        // iOS 16以降では、実際にデータを取得してみることで認証状態を確認
        Task {
            do {
                let calendar = Calendar.current
                let startOfDay = calendar.startOfDay(for: Date())
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                
                let predicate = HKQuery.predicateForSamples(
                    withStart: startOfDay,
                    end: endOfDay,
                    options: .strictStartDate
                )
                
                let query = HKStatisticsQuery(
                    quantityType: stepType,
                    quantitySamplePredicate: predicate,
                    options: .cumulativeSum
                ) { [weak self] _, result, error in
                    
                    DispatchQueue.main.async {
                        let wasAuthorized = self?.isAuthorized ?? false
                        
                        // エラーがなく、データが取得できる場合は認証済み
                        let canAccessData = (error == nil) && (result != nil)
                        
                        print("📋 HealthKit Authorization Status:")
                        print("   - Raw status: \(authStatus.rawValue)")
                        print("   - Status description: \(self?.getStatusDescription(authStatus) ?? "unknown")")
                        print("   - Can access data: \(canAccessData)")
                        print("   - Error: \(error?.localizedDescription ?? "none")")
                        print("   - Was authorized: \(wasAuthorized)")
                        print("   - Available: \(self?.isHealthKitAvailable ?? false)")
                        
                        // 実際のデータアクセス可否で認証状態を判定
                        self?.isAuthorized = canAccessData
                        
                        print("   - Is authorized: \(self?.isAuthorized ?? false)")
                        
                        if self?.isAuthorized == true && !wasAuthorized {
                            print("✅ Authorization granted! Fetching steps...")
                            Task {
                                await self?.fetchTodaySteps()
                                self?.enableBackgroundUpdates()
                            }
                        }
                    }
                }
                
                healthStore.execute(query)
                
            } catch {
                print("❌ Error checking authorization: \(error)")
                DispatchQueue.main.async {
                    self.isAuthorized = false
                }
            }
        }
    }
    
    private func getStatusDescription(_ status: HKAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "Not Determined"
        case .sharingDenied:
            return "Sharing Denied"
        case .sharingAuthorized:
            return "Sharing Authorized"
        @unknown default:
            return "Unknown"
        }
    }
    
    // MARK: - Fetch Today's Steps
    @MainActor
    func fetchTodaySteps() async {
        guard isAuthorized else {
            print("❌ HealthKit not authorized")
            return
        }
        
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )
        
        let query = HKStatisticsQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { [weak self] _, result, error in
            
            if let error = error {
                print("❌ Error fetching steps: \(error)")
                return
            }
            
            guard let result = result,
                  let sum = result.sumQuantity() else {
                print("⚠️ No step data available")
                Task { @MainActor in
                    self?.dailySteps = 0
                }
                return
            }
            
            let steps = Int(sum.doubleValue(for: HKUnit.count()))
            print("📊 Today's steps: \(steps)")
            
            Task { @MainActor in
                self?.dailySteps = steps
                self?.saveDailyStepsToFirebase(steps)
            }
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Background Updates
    func enableBackgroundUpdates() {
        guard isAuthorized else { return }
        
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        
        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] query, completion, error in
            if let error = error {
                print("❌ Background update error: \(error)")
                completion()
                return
            }
            
            Task {
                await self?.fetchTodaySteps()
                completion()
            }
        }
        
        healthStore.execute(query)
        healthStore.enableBackgroundDelivery(for: stepType, frequency: .immediate) { success, error in
            if success {
                print("✅ Background delivery enabled for steps")
            } else {
                print("❌ Failed to enable background delivery: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    // MARK: - Firebase Integration
    private func saveDailyStepsToFirebase(_ steps: Int) {
        guard let userId = currentUserId else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        
        let stepsData: [String: Any] = [
            "steps": steps,
            "date": dateString,
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        db.collection("users").document(userId).collection("dailySteps").document(dateString).setData(stepsData) { error in
            if let error = error {
                print("❌ Error saving steps to Firebase: \(error)")
            } else {
                print("✅ Steps saved to Firebase: \(steps)")
            }
        }
    }
    
    private func loadDailyStepsFromFirebase() {
        guard let userId = currentUserId else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        
        db.collection("users").document(userId).collection("dailySteps").document(dateString)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error loading steps from Firebase: \(error)")
                    return
                }
                
                guard let data = snapshot?.data(),
                      let steps = data["steps"] as? Int else {
                    print("ℹ️ No steps data found in Firebase for today")
                    return
                }
                
                DispatchQueue.main.async {
                    self?.dailySteps = steps
                    print("📊 Loaded steps from Firebase: \(steps)")
                }
            }
    }
    
    func getStepsHistory(days: Int = 7) async -> [String: Int] {
        guard let userId = currentUserId else { return [:] }
        
        var stepsHistory: [String: Int] = [:]
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        do {
            for i in 0..<days {
                let date = calendar.date(byAdding: .day, value: -i, to: Date()) ?? Date()
                let dateString = dateFormatter.string(from: date)
                
                let snapshot = try await db.collection("users").document(userId)
                    .collection("dailySteps").document(dateString).getDocument()
                
                if let data = snapshot.data(),
                   let steps = data["steps"] as? Int {
                    stepsHistory[dateString] = steps
                } else {
                    stepsHistory[dateString] = 0
                }
            }
        } catch {
            print("❌ Error fetching steps history: \(error)")
        }
        
        return stepsHistory
    }
}