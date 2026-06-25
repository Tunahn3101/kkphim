//
//  MovieDetailView.swift
//  kkphim
//
//  Created by Antigravity on 25/6/26.
//

import SwiftUI

struct MovieDetailView: View {
    let movieSlug: String
    let movieTitle: String
    
    @StateObject private var viewModel = MovieDetailViewModel()
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    @State private var selectedEpisode: Episode? = nil
    @State private var selectedServerIndex = 0
    @State private var showPlayer = false
    @State private var isExpandedContent = false
    
    // Adaptive theme colors
    private var backgroundColor: Color {
        isDarkMode ? Color(red: 0.07, green: 0.07, blue: 0.08) : Color(.systemGroupedBackground)
    }
    
    var body: some View {
        ZStack {
            // Adaptive Background
            backgroundColor
                .ignoresSafeArea()
            
            if viewModel.isLoading {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .red))
                        .scaleEffect(1.5)
                    Text("Đang tải chi tiết phim...")
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    Text(error)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button(action: {
                        Task {
                            await viewModel.fetchDetail(slug: movieSlug)
                        }
                    }) {
                        Text("Thử lại")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.red)
                            .cornerRadius(8)
                    }
                }
            } else if let movie = viewModel.movieDetail {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header section with Banner and Poster
                        headerSection(movie)
                        
                        VStack(alignment: .leading, spacing: 20) {
                            // Title & Quick Info
                            titleSection(movie)
                            
                            // Watch Now Button
                            playButtonSection(movie)
                            
                            // Synopsis
                            synopsisSection(movie)
                            
                            // Cast & Director & Details
                            castAndDetailsSection(movie)
                            
                            // Episode Server Selector & Episode Grid
                            episodesSection(movie)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
                .ignoresSafeArea(.container, edges: .top)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Quay lại")
                    }
                    .foregroundColor(.primary)
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .task {
            await viewModel.fetchDetail(slug: movieSlug)
        }
        .fullScreenCover(item: $selectedEpisode) { episode in
            if let url = URL(string: episode.linkM3u8) {
                MoviePlayerView(
                    videoURL: url,
                    title: viewModel.movieDetail?.name ?? movieTitle,
                    episodeName: episode.name
                )
            } else {
                Text("Đường dẫn video lỗi")
            }
        }
    }
    
    // MARK: - Subviews
    
    /// banner mờ ảo phía sau kết hợp poster sắc nét phía trước
    @ViewBuilder
    private func headerSection(_ movie: MovieDetail) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Blurred Background Banner
            AsyncImage(url: movie.fullPosterURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.opacity(0.2)
            }
            .frame(height: 320)
            .clipped()
            .blur(radius: 20)
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.3),
                        backgroundColor.opacity(0.0),
                        backgroundColor
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // Poster and overlay title
            HStack(alignment: .bottom, spacing: 16) {
                AsyncImage(url: movie.fullPosterURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ProgressView()
                        .frame(width: 110, height: 165)
                        .background(Color.gray.opacity(0.3))
                }
                .frame(width: 110, height: 165)
                .cornerRadius(8)
                .shadow(radius: 8)
                
                VStack(alignment: .leading, spacing: 6) {
                    // Type Badge (Phim bộ / Phim lẻ)
                    Text(movie.type == "series" ? "PHIM BỘ" : "PHIM LẺ")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                    
                    Text(movie.name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(movie.originName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.bottom, 10)
            }
            .padding(.horizontal, 16)
        }
    }
    
    /// Thông tin tiêu đề và tóm tắt nhanh
    @ViewBuilder
    private func titleSection(_ movie: MovieDetail) -> some View {
        HStack(spacing: 12) {
            Text("\(movie.year)")
            Text("•")
            Text(movie.quality)
            Text("•")
            Text(movie.lang)
            if !movie.time.isEmpty {
                Text("•")
                Text(movie.time)
            }
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundColor(.secondary)
    }
    
    /// Nút phát tập đầu tiên ngay lập tức
    @ViewBuilder
    private func playButtonSection(_ movie: MovieDetail) -> some View {
        Button(action: {
            if let firstServer = viewModel.episodeServers.first,
               let firstEpisode = firstServer.serverData.first {
                self.selectedEpisode = firstEpisode
            }
        }) {
            HStack {
                Image(systemName: "play.fill")
                Text("Xem ngay")
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.red)
            .cornerRadius(8)
        }
        .disabled(viewModel.episodeServers.isEmpty || viewModel.episodeServers.first?.serverData.isEmpty == true)
        .opacity(viewModel.episodeServers.isEmpty ? 0.6 : 1.0)
    }
    
    /// Tóm tắt nội dung phim có thể thu gọn/mở rộng
    @ViewBuilder
    private func synopsisSection(_ movie: MovieDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nội dung phim")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
            
            // Clean HTML description to simple text
            let cleanedDescription = movie.content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
            
            Text(cleanedDescription)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .lineLimit(isExpandedContent ? nil : 4)
                .lineSpacing(4)
            
            Button(action: {
                withAnimation {
                    isExpandedContent.toggle()
                }
            }) {
                Text(isExpandedContent ? "Thu gọn" : "Xem thêm")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.red)
            }
        }
    }
    
    /// Chi tiết về diễn viên, đạo diễn, thể loại
    @ViewBuilder
    private func castAndDetailsSection(_ movie: MovieDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !movie.director.isEmpty {
                HStack(alignment: .top) {
                    Text("Đạo diễn:")
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)
                    Text(movie.director.joined(separator: ", "))
                        .foregroundColor(.primary)
                }
                .font(.system(size: 13))
            }
            
            if !movie.actor.isEmpty && movie.actor.first?.isEmpty == false {
                HStack(alignment: .top) {
                    Text("Diễn viên:")
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)
                    Text(movie.actor.joined(separator: ", "))
                        .foregroundColor(.primary)
                        .lineLimit(3)
                }
                .font(.system(size: 13))
            }
            
            // Thể loại tags
            VStack(alignment: .leading, spacing: 8) {
                Text("Thể loại")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(movie.category) { cat in
                            Text(cat.name)
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.primary.opacity(0.08))
                                .foregroundColor(.primary.opacity(0.9))
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
    }
    
    /// Phần danh sách tập phim theo từng server
    @ViewBuilder
    private func episodesSection(_ movie: MovieDetail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Danh sách tập phim")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            if viewModel.episodeServers.isEmpty {
                Text("Thông tin tập phim đang cập nhật.")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
            } else {
                // Server selector if multiple servers exist
                if viewModel.episodeServers.count > 1 {
                    Picker("Server", selection: $selectedServerIndex) {
                        ForEach(0..<viewModel.episodeServers.count, id: \.self) { index in
                            Text(viewModel.episodeServers[index].serverName)
                                .tag(index)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.bottom, 8)
                }
                
                // Episodes Grid
                let server = viewModel.episodeServers[selectedServerIndex]
                let columns = [
                    GridItem(.adaptive(minimum: 75, maximum: 100), spacing: 10)
                ]
                
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(server.serverData) { episode in
                        Button(action: {
                            self.selectedEpisode = episode
                        }) {
                            Text(episode.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.primary.opacity(0.08))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                                        )
                                )
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        MovieDetailView(movieSlug: "vo-von-hien-luong", movieTitle: "Vợ Vốn Hiền Lương")
    }
}
