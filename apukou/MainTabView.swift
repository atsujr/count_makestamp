//
//  MainTabView.swift
//  apukou
//
//  Created by Claude on 2025/08/08.
//

import SwiftUI

struct MainTabView: View {
    
    var body: some View {
        ZStack {      
            TabView {
            NavigationView {
                StickerAcquisitionView()
            }
            .tabItem {
                Image(systemName: "shoeprints.fill")
            }
            
            NavigationView {
                StickerNotebookView()
            }
            .tabItem {
                Image(systemName: "book.fill")
            }
            
            NavigationView {
                UserProfileView()
            }
            .tabItem {
                Image(systemName: "person.crop.circle.fill")
            }
            }
            .accentColor(Color(red: 245/255, green: 114/255, blue: 182/255))
            .onAppear {
                
                // TabBarの背景を白に設定
                let appearance = UITabBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = UIColor.white
                UITabBar.appearance().standardAppearance = appearance
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }
            .preferredColorScheme(.light)
        }
    }
}

#Preview {
    MainTabView()
}
