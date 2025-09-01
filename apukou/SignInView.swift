//
//  SignInView.swift
//  apukou
//
//  Created by yuka on 2025/08/08.
//

import SwiftUI

struct SignInView: View {
    @ObservedObject private var userManager = UserManager.shared
    
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var showingSignUp = false
    @State private var animateGradient = false
    
    var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty
    }
    
    private let lightBlue = Color(red: 162/255, green: 242/255, blue: 251/255)
    private let lightPink = Color(red: 255/255, green: 202/255, blue: 227/255)
    private let lightPurple = Color(red: 221/255, green: 191/255, blue: 255/255)
    private let darkPink = Color(red: 245/255, green: 114/255, blue: 182/255) //#F572B6
    private let darkBlue = Color(red: 37/255, green: 162/255, blue: 220/255) //#25A2DC
    private let darkPurple = Color(red: 211/255, green: 123/255, blue: 255/255)//#D37BFF
    
    // MeshGradient背景
    private var meshGradientBackground: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white
                
                RadialGradient(
                    colors: [lightBlue.opacity(0.6), Color.clear],
                    center: UnitPoint(x: animateGradient ? 0.3 : 0.2, y: animateGradient ? 0.2 : 0.1),
                    startRadius: 0,
                    endRadius: geometry.size.width * (animateGradient ? 0.7 : 0.6)
                )
                
                RadialGradient(
                    colors: [lightPink.opacity(0.5), Color.clear],
                    center: UnitPoint(x: animateGradient ? 0.7 : 0.8, y: animateGradient ? 0.3 : 0.2),
                    startRadius: 0,
                    endRadius: geometry.size.width * (animateGradient ? 0.6 : 0.5)
                )
                
                RadialGradient(
                    colors: [lightPurple.opacity(0.4), Color.clear],
                    center: UnitPoint(x: animateGradient ? 0.2 : 0.1, y: animateGradient ? 0.5 : 0.6),
                    startRadius: 0,
                    endRadius: geometry.size.height * (animateGradient ? 0.5 : 0.4)
                )
                
                RadialGradient(
                    colors: [lightBlue.opacity(0.3), Color.clear],
                    center: UnitPoint(x: animateGradient ? 0.8 : 0.7, y: animateGradient ? 0.6 : 0.7),
                    startRadius: 0,
                    endRadius: geometry.size.width * (animateGradient ? 0.5 : 0.45)
                )
                
                RadialGradient(
                    colors: [lightPink.opacity(0.4), Color.clear],
                    center: UnitPoint(x: animateGradient ? 0.4 : 0.5, y: animateGradient ? 0.5 : 0.4),
                    startRadius: 0,
                    endRadius: min(geometry.size.width, geometry.size.height) * (animateGradient ? 0.4 : 0.35)
                )
                
                RadialGradient(
                    colors: [lightPurple.opacity(0.3), Color.clear],
                    center: UnitPoint(x: animateGradient ? 0.8 : 0.9, y: animateGradient ? 0.8 : 0.9),
                    startRadius: 0,
                    endRadius: geometry.size.height * (animateGradient ? 0.35 : 0.3)
                )
            }
            .blendMode(.multiply)
            //            .animation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true), value: animateGradient)
        }
        .ignoresSafeArea()
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                meshGradientBackground
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        Text("Petap")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(darkPurple)
                        
                            .padding(.top, 80)
                        
                        // Form
                        VStack(spacing: 24) {
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
//                                    .foregroundColor(Color.gray.opacity(0.5))
                            }
                            
                            // パスワード
                            VStack(alignment: .leading, spacing: 8) {
                                Text("パスワード")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                HStack {
                                    Group {
                                        if showPassword {
                                            TextField("パスワード", text: $password)
                                        } else {
                                            SecureField("パスワード", text: $password)
                                        }
                                    }
                                    .textContentType(.password)
                                    
                                    Button {
                                        showPassword.toggle()
                                    } label: {
                                        Image(systemName: showPassword ? "eye.slash" : "eye")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .textFieldStyle(.roundedBorder)
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
                        
                        // Buttons
                        VStack(spacing: 16) {
                            // Sign In Button
                            Button {
                                Task {
                                    await userManager.signIn(email: email, password: password)
                                }
                            } label: {
                                HStack {
                                    if userManager.isLoading {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .foregroundColor(.white)
                                    }
                                    Text("ログイン")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(isFormValid && !userManager.isLoading ? darkPurple : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(!isFormValid || userManager.isLoading)
                            
                            // Sign Up Button
                            Button {
                                showingSignUp = true
                            } label: {
                                Text("アカウント作成")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.white)
                                    .foregroundColor(darkPurple)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(darkPurple, lineWidth: 2)
                                    )
                            }
                            .disabled(userManager.isLoading)
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 60)
                    }
                }
            }
            .sheet(isPresented: $showingSignUp) {
                SignUpView()
            }
            .preferredColorScheme(.light)
        }
    }
}

#Preview {
    SignInView()
}
