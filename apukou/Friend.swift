//
//  Friend.swift
//  apukou
//
//  Created by yuka on 2025/07/16.
//

import SwiftUI
import FirebaseFirestore

// 友達のアバター表示コンポーネント
struct FriendAvatarView: View {
    let friend: Friend
    let size: CGFloat
    
    init(friend: Friend, size: CGFloat = 40) {
        self.friend = friend
        self.size = size
    }
    
    var body: some View {
        Group {
            if let profileImageURL = friend.profileImageURL, !profileImageURL.isEmpty {
                AsyncImage(url: URL(string: profileImageURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                } placeholder: {
                    Image(systemName: friend.avatarName)
                        .font(.system(size: size * 0.6))
                        .foregroundColor(.blue)
                        .frame(width: size, height: size)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
            } else {
                Image(systemName: friend.avatarName)
                    .font(.system(size: size * 0.6))
                    .foregroundColor(.blue)
                    .frame(width: size, height: size)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
            }
        }
    }
}

struct Friend: Identifiable, Codable {
    @DocumentID var id: String?
    let name: String
    let username: String
    let avatarName: String
    let profileImageURL: String?
    let userId: String // ユーザーのID
    
    init(id: String? = nil, name: String, username: String, avatarName: String, profileImageURL: String? = nil, userId: String) {
        self.id = id
        self.name = name
        self.username = username
        self.avatarName = avatarName
        self.profileImageURL = profileImageURL
        self.userId = userId
    }
}
