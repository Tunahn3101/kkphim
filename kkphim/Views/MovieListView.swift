//
//  MovieListView.swift
//  kkphim
//
//  Created by Antigravity on 25/6/26.
//

import SwiftUI

struct MovieListView: View {
    @StateObject private var viewModel = MovieListViewModel()
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    @FocusState private var isSearchFocused: Bool
    @State private var showFilterSheet = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]
    
    // Adaptive theme colors
    private var backgroundColor: Color {
        isDarkMode ? Color(red: 0.07, green: 0.07, blue: 0.08) : Color(.systemGroupedBackground)
    }
    
    private var cardBackgroundColor: Color {
        isDarkMode ? Color(red: 0.15, green: 0.15, blue: 0.17) : Color(.secondarySystemGroupedBackground)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background Tap to dismiss keyboard
                backgroundColor
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isSearchFocused = false
                    }
                
                VStack(spacing: 0) {
                    // Search and Filter Header
                    searchAndFilterHeader
                    
                    // Active Filters Alert (if any)
                    activeFiltersIndicator
                    
                    // Horizontal category tabs
                    categoryTabsSection
                    
                    if viewModel.isLoading && viewModel.movies.isEmpty {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .red))
                            .scaleEffect(1.5)
                        Spacer()
                    } else if let error = viewModel.errorMessage {
                        errorView(error)
                    } else if viewModel.movies.isEmpty {
                        emptyView
                    } else {
                        // Movie Grid
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 18) {
                                ForEach(viewModel.movies) { movie in
                                    NavigationLink(
                                        destination: MovieDetailView(
                                            movieSlug: movie.slug,
                                            movieTitle: movie.name
                                        )
                                    ) {
                                        MovieCardView(movie: movie, cardBg: cardBackgroundColor)
                                            .onAppear {
                                                // Trigger loading more when scroll reaches last items
                                                if movie.id == viewModel.movies.last?.id {
                                                    Task {
                                                        await viewModel.loadMoreMovies()
                                                    }
                                                }
                                            }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            
                            // Bottom loading indicator for pagination
                            if viewModel.isFetchingMore {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .red))
                                    .padding(.vertical, 12)
                            }
                        }
                        .refreshable {
                            await viewModel.loadMovies(isRefresh: true)
                        }
                        // Dismiss keyboard when dragging/scrolling
                        .simultaneousGesture(
                            DragGesture().onChanged { _ in
                                isSearchFocused = false
                            }
                        )
                    }
                }
            }
            .navigationTitle("KKPhim")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("KKPHIM")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.red)
                        .tracking(2)
                }
                
                // Light / Dark Mode Toggle Button
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isDarkMode.toggle()
                    }) {
                        Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(isDarkMode ? .yellow : .primary)
                    }
                }
            }
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .sheet(isPresented: $showFilterSheet) {
                FilterSheetView(viewModel: viewModel)
            }
            .task {
                if viewModel.movies.isEmpty {
                    await viewModel.loadMovies()
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    /// Thanh tìm kiếm thông minh kết hợp nút Lọc bộ lọc
    private var searchAndFilterHeader: some View {
        HStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Tìm kiếm phim...", text: $viewModel.searchText)
                    .focused($isSearchFocused)
                    .foregroundColor(.primary)
                    .font(.system(size: 15))
                    .autocorrectionDisabled()
                
                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(cardBackgroundColor)
            .cornerRadius(8)
            
            // Filter Button
            Button(action: {
                isSearchFocused = false
                showFilterSheet = true
            }) {
                Image(systemName: viewModel.isFilterActive ? "slider.horizontal.3.line.between.interpolated.demarcation" : "slider.horizontal.3")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(viewModel.isFilterActive ? .white : .primary)
                    .padding(10)
                    .background(viewModel.isFilterActive ? Color.red : cardBackgroundColor)
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    /// Hiển thị các nhãn bộ lọc đang hoạt động
    @ViewBuilder
    private var activeFiltersIndicator: some View {
        if viewModel.isFilterActive {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Text("Bộ lọc đang bật:")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    // Loại phim badge
                    filterBadge(text: viewModel.selectedFilterType == "phim-le" ? "Phim lẻ" :
                                    viewModel.selectedFilterType == "phim-bo" ? "Phim bộ" :
                                    viewModel.selectedFilterType == "hoat-hinh" ? "Hoạt hình" : "TV Shows")
                    
                    // Thể loại badge
                    if let genre = viewModel.selectedGenre {
                        filterBadge(text: genre.name)
                    }
                    
                    // Quốc gia badge
                    if let country = viewModel.selectedCountry {
                        filterBadge(text: country.name)
                    }
                    
                    // Năm badge
                    if let year = viewModel.selectedYear {
                        filterBadge(text: "\(year)")
                    }
                    
                    // Clear button
                    Button(action: {
                        Task {
                            await viewModel.clearFilters()
                        }
                    }) {
                        Text("Xóa hết")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.15))
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }
        }
    }
    
    private func filterBadge(text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(cardBackgroundColor)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.red.opacity(0.5), lineWidth: 0.5)
            )
    }
    
    /// Tab chọn danh mục chính
    private var categoryTabsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(MovieCategory.allCases) { category in
                    Button(action: {
                        isSearchFocused = false
                        viewModel.selectedCategory = category
                    }) {
                        Text(category.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                viewModel.selectedCategory == category && !viewModel.isFilterActive ? Color.red : cardBackgroundColor
                            )
                            .foregroundColor(
                                viewModel.selectedCategory == category && !viewModel.isFilterActive ? .white : .primary
                            )
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    /// Giao diện lỗi
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.icloud")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text(message)
                .foregroundColor(.secondary)
                .font(.system(size: 15))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button(action: {
                Task {
                    await viewModel.loadMovies(isRefresh: true)
                }
            }) {
                Text("Thử lại")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.red)
                    .cornerRadius(6)
            }
            Spacer()
        }
    }
    
    /// Giao diện trống
    private var emptyView: some View {
        VStack {
            Spacer()
            Image(systemName: "film")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
            Text("Không tìm thấy bộ phim nào phù hợp.")
                .foregroundColor(.secondary)
                .font(.system(size: 15))
            Spacer()
        }
    }
}

// MARK: - Filter Sheet View

struct FilterSheetView: View {
    @ObservedObject var viewModel: MovieListViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var tempType: String
    @State private var tempGenre: Category?
    @State private var tempCountry: Country?
    @State private var tempYear: Int?
    
    init(viewModel: MovieListViewModel) {
        self.viewModel = viewModel
        _tempType = State(initialValue: viewModel.selectedFilterType)
        _tempGenre = State(initialValue: viewModel.selectedGenre)
        _tempCountry = State(initialValue: viewModel.selectedCountry)
        _tempYear = State(initialValue: viewModel.selectedYear)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Loại phim
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Loại phim")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Picker("Loại phim", selection: $tempType) {
                            Text("Phim lẻ").tag("phim-le")
                            Text("Phim bộ").tag("phim-bo")
                            Text("Hoạt hình").tag("hoat-hinh")
                            Text("TV Shows").tag("tv-shows")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    Divider()
                    
                    // Thể loại
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Thể loại")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.primary)
                        
                        if viewModel.genres.isEmpty {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 10)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 95))], spacing: 8) {
                                Button(action: { tempGenre = nil }) {
                                    filterOptionTag(text: "Tất cả", isSelected: tempGenre == nil)
                                }
                                
                                ForEach(viewModel.genres) { genre in
                                    Button(action: { tempGenre = genre }) {
                                        filterOptionTag(text: genre.name, isSelected: tempGenre?.id == genre.id)
                                    }
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Quốc gia
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quốc gia")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.primary)
                        
                        if viewModel.countries.isEmpty {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 10)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                                Button(action: { tempCountry = nil }) {
                                    filterOptionTag(text: "Tất cả", isSelected: tempCountry == nil)
                                }
                                
                                ForEach(viewModel.countries) { country in
                                    Button(action: { tempCountry = country }) {
                                        filterOptionTag(text: country.name, isSelected: tempCountry?.id == country.id)
                                    }
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Năm phát hành
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Năm phát hành")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.primary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                Button(action: { tempYear = nil }) {
                                    filterOptionTag(text: "Tất cả", isSelected: tempYear == nil)
                                }
                                
                                ForEach(viewModel.availableYears, id: \.self) { year in
                                    Button(action: { tempYear = year }) {
                                        filterOptionTag(text: "\(year)", isSelected: tempYear == year)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Bộ lọc phim")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Xóa bộ lọc") {
                        Task {
                            await viewModel.clearFilters()
                            dismiss()
                        }
                    }
                    .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Áp dụng") {
                        Task {
                            await viewModel.applyFilters(
                                genre: tempGenre,
                                country: tempCountry,
                                year: tempYear,
                                type: tempType
                            )
                            dismiss()
                        }
                    }
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                }
            }
            .task {
                await viewModel.loadFilters()
            }
        }
    }
    
    // Tag nút bộ lọc
    private func filterOptionTag(text: String, isSelected: Bool) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.red : Color.gray.opacity(0.15))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(6)
            .lineLimit(1)
    }
}

// MARK: - Reusable Movie Card Component

struct MovieCardView: View {
    let movie: Movie
    let cardBg: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Poster Image
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: movie.fullPosterURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ZStack {
                        cardBg
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .red))
                    }
                }
                .frame(height: 240)
                .cornerRadius(8)
                .clipped()
                .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 2)
                
                // Badge Year
                Text("\(movie.year)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(4)
                    .padding(6)
            }
            
            // Movie Info
            VStack(alignment: .leading, spacing: 2) {
                Text(movie.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(movie.originName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 2)
        }
    }
}

#Preview {
    MovieListView()
}
