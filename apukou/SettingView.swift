//
//  SettingView.swift
//  apukou
//
//  Created by yuka on 2025/08/10.
//

import SwiftUI
import CoreImage.CIFilterBuiltins
import AVFoundation
import AudioToolbox

struct SettingView: View {
    @ObservedObject private var userManager = UserManager.shared
    @State private var showingEditProfile = false
    @State private var showingSignOut = false
    @State private var showingPasswordReset = false
    @State private var showingAccountDelete = false
    @State private var showingProfileShare = false
    @Environment(\.dismiss) private var dismiss
    
    private var settingBackgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 255/255, green: 202/255, blue: 227/255),
                Color(red: 162/255, green: 242/255, blue: 251/255)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                settingBackgroundGradient
                
                ScrollView {
                VStack(spacing: 0) {
                    
                    // プロフィール関連
                    SettingSection(title: "プロフィール") {
                        SettingRow(
                            icon: "person.crop.circle.badge.checkmark",
                            title: "プロフィール編集",
                            color: .black
                        ) {
                            showingEditProfile = true
                        }
                        
                        SettingRow(
                            icon: "square.and.arrow.up",
                            title: "プロフィール共有",
                            color: .black
                        ) {
                            showingProfileShare = true
                        }
                    }
                    
                    // セキュリティ関連
                    SettingSection(title: "セキュリティ") {
                        SettingRow(
                            icon: "key.fill",
                            title: "パスワードをリセット",
                            color: .black
                        ) {
                            showingPasswordReset = true
                        }
                    }
                    
                    // アカウント関連
                    SettingSection(title: "アカウント") {
                        SettingRow(
                            icon: "rectangle.portrait.and.arrow.forward",
                            title: "ログアウト",
                            color: .black
                        ) {
                            showingSignOut = true
                        }
                        
                        SettingRow(
                            icon: "trash.fill",
                            title: "アカウント削除",
                            color: .black
                        ) {
                            showingAccountDelete = true
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.large)
            //            .toolbar {
            //                ToolbarItem(placement: .navigationBarTrailing) {
            //                    Button("完了") {
            //                        dismiss()
            //                    }
            //                }
            //            }
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView()
        }
        .alert("ログアウト", isPresented: $showingSignOut) {
            Button("キャンセル", role: .cancel) { }
            Button("ログアウト", role: .destructive) {
                userManager.signOut()
                dismiss()
            }
        } message: {
            Text("本当にログアウトしますか？")
        }
        .alert("パスワードリセット", isPresented: $showingPasswordReset) {
            Button("キャンセル", role: .cancel) { }
            Button("リセット")
                /*.foregroundColor(.white)*/{
                resetPassword()
            }
        } message: {
            Text("登録されているメールアドレスにパスワードリセット用のリンクを送信します。")
        }
        .alert("アカウント削除", isPresented: $showingAccountDelete) {
            Button("キャンセル", role: .cancel) { }
            Button("削除", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("この操作は元に戻せません。本当にアカウントを削除しますか？")
        }
        .sheet(isPresented: $showingProfileShare) {
            ProfileShareView(isPresented: $showingProfileShare)
        }
        .preferredColorScheme(.light)
    }
    
    private func resetPassword() {
        // Firebase Auth のパスワードリセット機能を実装
        guard let email = userManager.currentUser?.email else { return }
        userManager.sendPasswordResetEmail(email: email)
    }
    
    private func deleteAccount() {
        // アカウント削除機能を実装
        userManager.deleteAccount()
        dismiss()
    }
}

struct SettingSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.top, 24)
                .padding(.bottom, 8)
            
            VStack(spacing: 0) {
                content
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

struct SettingRow: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                    .frame(width: 24)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.black)
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
        }
        .buttonStyle(.plain)
    }
}

struct ProfileShareView: View {
    @Binding var isPresented: Bool
    @ObservedObject private var userManager = UserManager.shared
    @State private var showingQRScanner = false
    
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()
    
    private let mainBlue = Color(red: 162/255, green: 242/255, blue: 251/255) //#A2F2FB
    private let mainPink = Color(red: 255/255, green: 202/255, blue: 227/255) //#FFCAE3
    private let darkPink = Color(red: 245/255, green: 114/255, blue: 182/255) //#F572B6
    
    private var profileShareBackgroundGradient: some View {
        RadialGradient(
            gradient: Gradient(colors: [mainBlue, Color.white
            ]),
            center: .center,
            startRadius: 50,
            endRadius: 400
        )
        .ignoresSafeArea()
    }
    
    var body: some View {
            VStack(spacing: 32) {
                Spacer(minLength: 40)
                
                // プロフィール情報とQRコード
                VStack(spacing: 24) {
                    // プロフィール画像
                    if let profileImageURL = userManager.currentUser?.profileImageURL,
                       !profileImageURL.isEmpty {
                        AsyncImage(url: URL(string: profileImageURL)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } placeholder: {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 80))
                                .foregroundColor(.blue.opacity(0.7))
                                .frame(width: 100, height: 100)
                        }
                    } else {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 80))
                            .foregroundColor(.blue.opacity(0.7))
                            .frame(width: 100, height: 100)
                    }
                    
                    // 名前とユーザー名
                    VStack(spacing: 6) {
                        Text(userManager.currentUser?.name ?? "ユーザー名")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("@\(userManager.currentUser?.username ?? "username")")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    
                    // QRコード
                    if let qrCodeImage = generateQRCode() {
                        Image(uiImage: qrCodeImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 240, height: 240)
                            .background(Color.white)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                // アクションボタン
                VStack(spacing: 16) {
                    Button {
                        showingQRScanner = true
                    } label: {
                        HStack {
                            Image(systemName: "qrcode.viewfinder")
                            Text("QRコードをスキャン")
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(mainPink)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button {
                        presentShareSheet()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("共有")
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(mainPink)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                
                Spacer(minLength: 40)
            }
            .padding()
            .background(profileShareBackgroundGradient)
            .sheet(isPresented: $showingQRScanner) {
                QRScannerView()
            }
            .gesture(
                DragGesture()
                    .onEnded { value in
                        // 下向きスワイプでシートを閉じる
                        if value.translation.height > 100 && abs(value.translation.width) < 50 {
                            isPresented = false
                        }
                    }
            )
            .preferredColorScheme(.light)
    }
    
    private func generateQRCode() -> UIImage? {
        guard let user = userManager.currentUser else { return nil }
        
        // ユーザー情報をJSON形式で作成
        let qrContent = "apukou://user/\(user.username)"
        
        let data = Data(qrContent.utf8)
        filter.setValue(data, forKey: "inputMessage")
        
        if let outputImage = filter.outputImage {
            if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        
        return nil
    }
    
    private func getShareContent() -> String {
        guard let user = userManager.currentUser else { return "" }
        return "apukouで繋がろう！\n apukou://user/\(user.username)"
    }
    
    private func presentShareSheet() {
        let shareContent = getShareContent()
        let activityVC = UIActivityViewController(activityItems: [shareContent], applicationActivities: nil)
        
        // iPadのpopover対応
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            activityVC.popoverPresentationController?.sourceView = window
            activityVC.popoverPresentationController?.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
            activityVC.popoverPresentationController?.permittedArrowDirections = []
        }
        
        // 完了時のコールバック
        activityVC.completionWithItemsHandler = { _, completed, _, _ in
            if completed {
                DispatchQueue.main.async {
                    isPresented = false
                }
            }
        }
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            var presentingViewController = rootViewController
            while let presentedViewController = presentingViewController.presentedViewController {
                presentingViewController = presentedViewController
            }
            presentingViewController.present(activityVC, animated: true)
        }
    }
}

struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var scannedCode: String?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                // カメラビュー
                QRScannerRepresentable { qrCode in
                    handleQRCode(qrCode)
                }
                .ignoresSafeArea()
                
                // スキャンフレーム
                VStack {
                    Spacer()
                    
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 250, height: 250)
                        .overlay(
                            VStack {
                                HStack {
                                    Rectangle()
                                        .fill(Color.white)
                                        .frame(width: 30, height: 3)
                                    Spacer()
                                    Rectangle()
                                        .fill(Color.white)
                                        .frame(width: 30, height: 3)
                                }
                                Spacer()
                                HStack {
                                    Rectangle()
                                        .fill(Color.white)
                                        .frame(width: 30, height: 3)
                                    Spacer()
                                    Rectangle()
                                        .fill(Color.white)
                                        .frame(width: 30, height: 3)
                                }
                            }
                            .padding(20)
                        )
                    
                    Text("QRコードをフレーム内に合わせてください")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                        .padding(.top, 20)
                    
                    Spacer()
                }
            }
            .navigationTitle("QRスキャン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .alert("QRコード検出", isPresented: $showingAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text(alertMessage)
            }
            .preferredColorScheme(.light)
        }
    }
    
    private func handleQRCode(_ qrCode: String) {
        scannedCode = qrCode
        
        // apukouのプロフィールURLの場合
        if qrCode.hasPrefix("apukou://user/") {
            let username = String(qrCode.dropFirst("apukou://user/".count))
            alertMessage = "ユーザー \(username) のプロフィールを検出しました"
        } else {
            alertMessage = "QRコード: \(qrCode)"
        }
        
        showingAlert = true
    }
}

// MARK: - QRコードスキャナー
struct QRScannerRepresentable: UIViewRepresentable {
    let onQRCodeDetected: (String) -> Void
    
    func makeUIView(context: Context) -> QRScannerViewContainer {
        let scannerView = QRScannerViewContainer()
        scannerView.delegate = context.coordinator
        return scannerView
    }
    
    func updateUIView(_ uiView: QRScannerViewContainer, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onQRCodeDetected: onQRCodeDetected)
    }
    
    class Coordinator: NSObject, QRScannerDelegate {
        let onQRCodeDetected: (String) -> Void
        
        init(onQRCodeDetected: @escaping (String) -> Void) {
            self.onQRCodeDetected = onQRCodeDetected
        }
        
        func qrScannerDidDetectCode(_ qrCode: String) {
            onQRCodeDetected(qrCode)
        }
    }
}

protocol QRScannerDelegate: AnyObject {
    func qrScannerDidDetectCode(_ qrCode: String)
}

class QRScannerViewContainer: UIView {
    weak var delegate: QRScannerDelegate?
    
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var isScanning = true
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCamera()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCamera()
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            print("カメラが利用できません")
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            print("カメラ入力の設定に失敗しました: \(error)")
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            print("ビデオ入力を追加できませんでした")
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            print("メタデータ出力を追加できませんでした")
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = bounds
        previewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(previewLayer)
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

extension QRScannerViewContainer: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard isScanning else { return }
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            // QRコード検出時に振動
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            
            // 重複検出を防ぐため一時停止
            isScanning = false
            
            // デリゲートに通知
            delegate?.qrScannerDidDetectCode(stringValue)
            
            // 2秒後に再開
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.isScanning = true
            }
        }
    }
}

#Preview {
    SettingView()
}
