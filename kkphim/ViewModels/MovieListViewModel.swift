//
//  MovieListViewModel.swift
//  kkphim
//
//  Created by Antigravity on 25/6/26.
//

import Foundation
import Combine

enum MovieCategory: String, CaseIterable, Identifiable {
    case latest = "Mới nhất"
    case single = "Phim lẻ"
    case series = "Phim bộ"
    case cartoon = "Hoạt hình"
    case tvShows = "TV Shows"
    
    var id: String { self.rawValue }
    
    var apiSlug: String {
        switch self {
        case .latest: return "phim-moi-cap-nhat"
        case .single: return "phim-le"
        case .series: return "phim-bo"
        case .cartoon: return "hoat-hinh"
        case .tvShows: return "tv-shows"
        }
    }
}

@MainActor
class MovieListViewModel: ObservableObject {
    @Published var movies: [Movie] = []
    @Published var selectedCategory: MovieCategory = .latest {
        didSet {
            if oldValue != selectedCategory {
                searchText = ""
                // Xóa bộ lọc khi đổi danh mục chính ở tab bar
                selectedGenre = nil
                selectedCountry = nil
                selectedYear = nil
                resetPagination()
                Task {
                    await loadMovies(isRefresh: true)
                }
            }
        }
    }
    
    @Published var searchText: String = "" {
        didSet {
            // Hủy tác vụ tìm kiếm cũ nếu có
            searchTask?.cancel()
            
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if oldValue != searchText {
                    resetPagination()
                    Task {
                        await loadMovies(isRefresh: true)
                    }
                }
            } else {
                // Xóa bộ lọc khi người dùng gõ tìm kiếm
                selectedGenre = nil
                selectedCountry = nil
                selectedYear = nil
                
                searchTask = Task {
                    // Chờ 0.5 giây để tránh gọi API liên tục khi gõ (debounce)
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    guard !Task.isCancelled else { return }
                    resetPagination()
                    await loadMovies(isRefresh: true)
                }
            }
        }
    }
    
    @Published var isLoading = false
    @Published var isFetchingMore = false
    @Published var errorMessage: String? = nil
    
    // Bộ lọc đang kích hoạt
    @Published var selectedGenre: Category? = nil
    @Published var selectedCountry: Country? = nil
    @Published var selectedYear: Int? = nil
    @Published var selectedFilterType: String = "phim-le"
    
    // Danh sách bộ lọc tải về từ API
    @Published var genres: [Category] = []
    @Published var countries: [Country] = []
    let availableYears: [Int] = Array(2010...2026).reversed()
    
    var isFilterActive: Bool {
        selectedGenre != nil || selectedCountry != nil || selectedYear != nil
    }
    
    // Phân trang
    private var currentPage = 1
    private var totalPages = 1
    private var hasMorePages: Bool {
        currentPage < totalPages
    }
    
    private var searchTask: Task<Void, Never>? = nil
    private let apiService = APIService.shared
    
    func resetPagination() {
        movies = []
        currentPage = 1
        totalPages = 1
        errorMessage = nil
    }
    
    /// Tải danh sách các bộ lọc (Thể loại & Quốc gia) từ API
    func loadFilters() async {
        guard genres.isEmpty || countries.isEmpty else { return }
        do {
            async let fetchedGenres = apiService.fetchAllGenres()
            async let fetchedCountries = apiService.fetchAllCountries()
            
            let (g, c) = try await (fetchedGenres, fetchedCountries)
            self.genres = g
            self.countries = c
        } catch {
            print("Lỗi tải bộ lọc: \(error.localizedDescription)")
        }
    }
    
    /// Áp dụng bộ lọc mới
    func applyFilters(genre: Category?, country: Country?, year: Int?, type: String) async {
        self.selectedGenre = genre
        self.selectedCountry = country
        self.selectedYear = year
        self.selectedFilterType = type
        self.searchText = ""
        
        await loadMovies(isRefresh: true)
    }
    
    /// Xóa toàn bộ bộ lọc
    func clearFilters() async {
        self.selectedGenre = nil
        self.selectedCountry = nil
        self.selectedYear = nil
        
        await loadMovies(isRefresh: true)
    }
    
    /// Tải danh sách phim (Mới tinh hoặc Reload)
    func loadMovies(isRefresh: Bool = false) async {
        if isRefresh {
            resetPagination()
        }
        
        guard movies.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let result: (movies: [Movie], pagination: Pagination?)
            
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !query.isEmpty {
                result = try await apiService.searchMovies(keyword: query, page: currentPage)
            } else if isFilterActive {
                // Gọi API kết hợp bộ lọc
                result = try await apiService.fetchFilteredMovies(
                    type: selectedFilterType,
                    categorySlug: selectedGenre?.slug,
                    countrySlug: selectedCountry?.slug,
                    year: selectedYear,
                    page: currentPage
                )
            } else if selectedCategory == .latest {
                result = try await apiService.fetchLatestMovies(page: currentPage)
            } else {
                result = try await apiService.fetchMoviesByCategory(categorySlug: selectedCategory.apiSlug, page: currentPage)
            }
            
            self.movies = result.movies
            if let paging = result.pagination {
                self.totalPages = paging.totalPages
            }
        } catch {
            if !(error is CancellationError) {
                self.errorMessage = error.localizedDescription
            }
        }
        
        isLoading = false
    }
    
    /// Tải thêm phim khi cuộn xuống cuối (Infinite Scroll)
    func loadMoreMovies() async {
        guard !isLoading && !isFetchingMore && hasMorePages else { return }
        
        isFetchingMore = true
        let nextPage = currentPage + 1
        
        do {
            let result: (movies: [Movie], pagination: Pagination?)
            
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !query.isEmpty {
                result = try await apiService.searchMovies(keyword: query, page: nextPage)
            } else if isFilterActive {
                // Tải trang tiếp theo cho bộ lọc
                result = try await apiService.fetchFilteredMovies(
                    type: selectedFilterType,
                    categorySlug: selectedGenre?.slug,
                    countrySlug: selectedCountry?.slug,
                    year: selectedYear,
                    page: nextPage
                )
            } else if selectedCategory == .latest {
                result = try await apiService.fetchLatestMovies(page: nextPage)
            } else {
                result = try await apiService.fetchMoviesByCategory(categorySlug: selectedCategory.apiSlug, page: nextPage)
            }
            
            // Lọc trùng ID phim nếu có
            let newUniqueMovies = result.movies.filter { newMovie in
                !self.movies.contains(where: { $0.id == newMovie.id })
            }
            
            self.movies.append(contentsOf: newUniqueMovies)
            self.currentPage = nextPage
            if let paging = result.pagination {
                self.totalPages = paging.totalPages
            }
        } catch {
            print("Lỗi tải thêm phim: \(error.localizedDescription)")
        }
        
        isFetchingMore = false
    }
}
