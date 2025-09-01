//
//  EditProfileView.swift
//  apukou
//
//  Created by Claude on 2025/08/08.
//

import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @ObservedObject private var userManager = UserManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""

    @State private var selectedImage: PhotosPickerItem? = nil
    @State private var profileImage: UIImage? = nil

    private var backgroundGradient: some View {
        RadialGradient(
            gradient: Gradient(colors: [
                Color(red: 162/255, green: 242/255, blue: 251/255),
                Color.white
            ]),
            center: .center,
            startRadius: 50,
            endRadius: 400
        )
        .ignoresSafeArea()
    }

    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient

                Form {
                    Section {
                        HStack {
                            Spacer()
                            PhotosPicker(selection: $selectedImage, matching: .images) {
                                VStack(spacing: 8) {
                                    if let profileImage = profileImage {
                                        Image(uiImage: profileImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(Circle())
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.blue, lineWidth: 2)
                                            )
                                    } else if let profileImageURL = userManager.currentUser?.profileImageURL,
                                              !profileImageURL.isEmpty {
                                        AsyncImage(url: URL(string: profileImageURL)) { image in
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        } placeholder: {
                                            Image(systemName: "person.crop.circle")
                                                .font(.system(size: 60))
                                                .foregroundColor(.blue.opacity(0.7))
                                        }
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color.blue, lineWidth: 2)
                                        )
                                    } else {
                                        Image(systemName: "person.crop.circle")
                                            .font(.system(size: 60))
                                            .foregroundColor(.blue.opacity(0.7))
                                            .frame(width: 80, height: 80)
                                    }

                                    Text("画像を変更")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                            .onChange(of: selectedImage) { oldValue, newValue in
                                Task {
                                    if let newValue = newValue,
                                       let data = try? await newValue.loadTransferable(type: Data.self),
                                       let uiImage = UIImage(data: data) {
                                        profileImage = uiImage
                                    }
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }

                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("名前")
                                .font(.headline)
                            TextField("名前を入力", text: $name)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        .padding(.vertical, 4)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("ユーザーネーム")
                                .font(.headline)
                            TextField("ユーザーネームを入力", text: $username)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        .padding(.vertical, 4)
                    }

                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("自己紹介")
                                .font(.headline)
                            TextEditor(text: $bio)
                                .frame(minHeight: 100)
                                .padding(4)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .padding(.vertical, 4)
                    }
                }
                // ← Form に対して付与する
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .navigationTitle("プロフィール編集")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("キャンセル") { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("保存") {
                            Task { await saveProfile() }
                        }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                  username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                  userManager.isLoading)
                    }
                }
                .onAppear { loadCurrentUserData() }
                .alert("メッセージ", isPresented: $showingAlert) {
                    Button("OK") { }
                } message: {
                    Text(alertMessage)
                }
                .overlay {
                    if userManager.isLoading {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .overlay {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.2)
                            }
                    }
                }
            }
        }
        .preferredColorScheme(.light)
    }

    private func loadCurrentUserData() {
        if let user = userManager.currentUser {
            name = user.name
            username = user.username
            bio = user.bio ?? ""
        }
    }

    private func saveProfile() async {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertMessage = "名前とユーザーネームを入力してください"
            showingAlert = true
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)

        await userManager.updateUserProfile(
            name: trimmedName,
            username: trimmedUsername,
            bio: trimmedBio.isEmpty ? nil : trimmedBio,
            profileImage: profileImage
        )

        if let error = userManager.errorMessage {
            alertMessage = error
            showingAlert = true
        } else {
            alertMessage = "プロフィールを更新しました"
            showingAlert = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                dismiss()
            }
        }
    }
}

#Preview {
    EditProfileView()
}
