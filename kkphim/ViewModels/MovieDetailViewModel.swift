//
//  MovieDetailViewModel.swift
//  kkphim
//
//  Created by Antigravity on 25/6/26.
//

import Foundation
import Combine

@MainActor
class MovieDetailViewModel: ObservableObject {
    @Published var movieDetail: MovieDetail? = nil
    @Published var episodeServers: [EpisodeServer] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    private let apiService = APIService.shared
    
    /// Tải thông tin chi tiết phim từ slug
    func fetchDetail(slug: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await apiService.fetchMovieDetail(slug: slug)
            self.movieDetail = response.movie
            self.episodeServers = response.episodes
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}
