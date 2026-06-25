//
//  MoviePlayerView.swift
//  kkphim
//
//  Created by Antigravity on 25/6/26.
//

import SwiftUI
import AVKit

struct MoviePlayerView: View {
    let videoURL: URL
    let title: String
    let episodeName: String
    
    @State private var player: AVPlayer? = nil
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onAppear {
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                    }
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .red))
                        .scaleEffect(1.5)
                    
                    Text("Đang tải nguồn video...")
                        .foregroundColor(.gray)
                        .font(.system(size: 14, weight: .medium))
                }
            }
            
            // Custom close button on top-left if it is presented as a full screen cover
            VStack {
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.8))
                            .padding()
                    }
                    Spacer()
                }
                Spacer()
            }
        }
        .onAppear {
            setupAudioSession()
            self.player = AVPlayer(url: videoURL)
        }
        .onDisappear {
            self.player?.pause()
            self.player = nil
        }
        .statusBarHidden(true)
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Lỗi cấu hình âm thanh: \(error.localizedDescription)")
        }
    }
}

#Preview {
    MoviePlayerView(
        videoURL: URL(string: "https://v7.kkphimplayer7.com/20260623/AOthfNol/index.m3u8")!,
        title: "Vợ Vốn Hiền Lương",
        episodeName: "Tập 01"
    )
}
