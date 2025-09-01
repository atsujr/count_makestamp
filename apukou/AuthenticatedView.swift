//
//  AuthenticatedView.swift
//  apukou
//
//  Created by Claude on 2025/08/08.
//

import SwiftUI

struct AuthenticatedView: View {
    @ObservedObject private var userManager = UserManager.shared
    
    var body: some View {
        Group {
            if userManager.isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("読み込み中...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            } else if userManager.isAuthenticated {
                MainTabView()
            } else {
                SignInView()
            }
        }
    }
}

#Preview {
    AuthenticatedView()
}