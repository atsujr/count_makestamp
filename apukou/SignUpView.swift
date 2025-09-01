//
//  SignUpView.swift
//  apukou
//
//  Created by Claude on 2025/08/08.
//

import SwiftUI
import PhotosUI

struct SignUpView: View {
    @ObservedObject private var userManager = UserManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    
    @State private var selectedImage: PhotosPickerItem? = nil
    @State private var profileImage: UIImage? = nil
    
    private let mainBlue = Color(red: 162/255, green: 242/255, blue: 251/255) //#A2F2FB
    private let darkPurple = Color(red: 211/255, green: 123/255, blue: 255/255)//#D37BFF
    
    private var backgroundGradient: some View {
        RadialGradient(
            gradient: Gradient(colors: [mainBlue,Color.white]),
            center: .center,
            startRadius: 50,
            endRadius: 400
        )
        .ignoresSafeArea()
    }
    
    var isFormValid: Bool {
        !name.isEmpty &&
        !username.isEmpty &&
        !email.isEmpty &&
        password.count >= 6 &&
        password == confirmPassword
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                
                ScrollView {
                    VStack(spacing: 24) {
                    // Header
                        Text("アカウント作成")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    .padding(.top, 40)
                    
                    // Profile Image Picker
                    VStack(spacing: 12) {
                        PhotosPicker(selection: $selectedImage, matching: .images) {
                            VStack(spacing: 8) {
                                if let profileImage = profileImage {
                                    Image(uiImage: profileImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color.blue, lineWidth: 3)
                                        )
                                } else {
                                    Image(systemName: "person.crop.circle")
                                        .font(.system(size: 80))
                                        .foregroundColor(.blue.opacity(0.7))
                                        .frame(width: 100, height: 100)
                                }
                                
                                Text("プロフィール画像を選択")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        .onChange(of: selectedImage) { oldValue, newValue in
                            Task {
                                if let newValue = newValue {
                                    if let data = try? await newValue.loadTransferable(type: Data.self),
                                       let uiImage = UIImage(data: data) {
                                        profileImage = uiImage
                                    }
                                }
                            }
                        }
                    }
                    
                    // Form
                    VStack(spacing: 20) {
                        // 名前
                        VStack(alignment: .leading, spacing: 8) {
                            Text("名前")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextField("山田太郎", text: $name)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.name)
                        }
                        
                        // ユーザーネーム
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ユーザーネーム")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextField("yamada_taro", text: $username)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.username)
                                .autocapitalization(.none)
                        }
                        
                        // メールアドレス
                        VStack(alignment: .leading, spacing: 8) {
                            Text("メールアドレス")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextField("example@email.com", text: $email)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
//                                .foregroundColor(Color.gray.opacity(0.5))
                            
                        }
                        
                        // パスワード
                        VStack(alignment: .leading, spacing: 8) {
                            Text("パスワード")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Group {
                                    if showPassword {
                                        TextField("6文字以上", text: $password)
                                    } else {
                                        SecureField("6文字以上", text: $password)
                                    }
                                }
                                .textContentType(.newPassword)
                                
                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .textFieldStyle(.roundedBorder)
                        }
                        
                        // パスワード確認
                        VStack(alignment: .leading, spacing: 8) {
                            Text("パスワード確認")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Group {
                                    if showConfirmPassword {
                                        TextField("パスワードを再入力", text: $confirmPassword)
                                    } else {
                                        SecureField("パスワードを再入力", text: $confirmPassword)
                                    }
                                }
                                .textContentType(.newPassword)
                                
                                Button {
                                    showConfirmPassword.toggle()
                                } label: {
                                    Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .textFieldStyle(.roundedBorder)
                            
                            if !confirmPassword.isEmpty && password != confirmPassword {
                                Text("パスワードが一致しません")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Error Message
                    if let errorMessage = userManager.errorMessage {
                        Text(errorMessage)
                            .font(.body)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    // Sign Up Button
                    Button {
                        Task {
                            await userManager.signUp(
                                name: name,
                                username: username,
                                email: email,
                                password: password,
                                profileImage: profileImage
                            )
                            if userManager.isAuthenticated {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack {
                            if userManager.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            }
                            Text("アカウント作成")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isFormValid && !userManager.isLoading ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!isFormValid || userManager.isLoading)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // ナビゲーションバーを透明にする
                let appearance = UINavigationBarAppearance()
                appearance.configureWithTransparentBackground()
                UINavigationBar.appearance().standardAppearance = appearance
                UINavigationBar.appearance().scrollEdgeAppearance = appearance
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.light)
    }
}

#Preview {
    SignUpView()
}
