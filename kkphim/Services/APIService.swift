//
//  APIService.swift
//  kkphim
//
//  Created by Antigravity on 25/6/26.
//

import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Đường dẫn API không hợp lệ."
        case .noData:
            return "Không nhận được dữ liệu từ máy chủ."
        case .decodingError(let error):
            return "Lỗi xử lý dữ liệu: \(error.localizedDescription)"
        case .serverError(let message):
            return "Lỗi máy chủ: \(message)"
        }
    }
}

class APIService {
    static let shared = APIService()
    
    private let baseURL = "https://phimapi.com"
    
    private init() {}
    
    private func decodingDetails(from error: DecodingError) -> (path: String, reason: String, underlying: String?) {
        switch error {
        case .typeMismatch(_, let context):
            let path = (context.codingPath.map { $0.stringValue }.joined(separator: "."))
            let reason = context.debugDescription
            let underlying = (context.underlyingError as NSError?)?.localizedDescription
            return (path.isEmpty ? "<root>" : path, reason, underlying)
        case .valueNotFound(_, let context):
            let path = (context.codingPath.map { $0.stringValue }.joined(separator: "."))
            let reason = context.debugDescription
            let underlying = (context.underlyingError as NSError?)?.localizedDescription
            return (path.isEmpty ? "<root>" : path, reason, underlying)
        case .keyNotFound(let missingKey, let context):
            let path = (context.codingPath.map { $0.stringValue }.joined(separator: "."))
            var reason = context.debugDescription
            reason = "Key not found: \(missingKey.stringValue). " + reason
            let underlying = (context.underlyingError as NSError?)?.localizedDescription
            return (path.isEmpty ? "<root>" : path, reason, underlying)
        case .dataCorrupted(let context):
            let path = (context.codingPath.map { $0.stringValue }.joined(separator: "."))
            let reason = context.debugDescription
            let underlying = (context.underlyingError as NSError?)?.localizedDescription
            return (path.isEmpty ? "<root>" : path, reason, underlying)
        @unknown default:
            return ("<unknown>", "Unknown decoding error", nil)
        }
    }
    
    /// Lấy danh sách phim mới cập nhật (Format 1)
    func fetchLatestMovies(page: Int) async throws -> (movies: [Movie], pagination: Pagination?) {
        guard let url = URL(string: "\(baseURL)/danh-sach/phim-moi-cap-nhat?page=\(page)") else {
            throw APIError.invalidURL
        }
        
        let start = CFAbsoluteTimeGetCurrent()
        NetworkLogger.logRequest(url)
        let (data, response) = try await URLSession.shared.data(from: url)
        NetworkLogger.logResponse(url, response: response, data: data, error: nil, startTime: start)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            NetworkLogger.logResponse(url, response: response, data: nil, error: APIError.serverError("HTTP status not OK"), startTime: start)
            throw APIError.serverError("Máy chủ trả về lỗi hoặc không phản hồi.")
        }
        
        do {
            let decodedResponse = try JSONDecoder().decode(MovieResponse.self, from: data)
            if decodedResponse.status {
                return (decodedResponse.items, decodedResponse.pagination)
            } else {
                throw APIError.serverError(decodedResponse.msg)
            }
        } catch {
            #if DEBUG
            if let decErr = error as? DecodingError {
                let details = decodingDetails(from: decErr)
                print("🧩 DecodingError at \(details.path): \(details.reason)")
                if let underlying = details.underlying { print("↪︎ Underlying: \(underlying)") }
            } else {
                print("🧩 Decode failed: \(error.localizedDescription)")
            }
            #endif
            throw APIError.decodingError(error)
        }
    }
    
    /// Lấy phim theo danh mục (phim-le, phim-bo, hoat-hinh, tv-shows) (Format 2)
    func fetchMoviesByCategory(categorySlug: String, page: Int) async throws -> (movies: [Movie], pagination: Pagination?) {
        guard let url = URL(string: "\(baseURL)/v1/api/danh-sach/\(categorySlug)?page=\(page)") else {
            throw APIError.invalidURL
        }
        
        let start = CFAbsoluteTimeGetCurrent()
        NetworkLogger.logRequest(url)
        let (data, response) = try await URLSession.shared.data(from: url)
        NetworkLogger.logResponse(url, response: response, data: data, error: nil, startTime: start)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            NetworkLogger.logResponse(url, response: response, data: nil, error: APIError.serverError("HTTP status not OK"), startTime: start)
            throw APIError.serverError("Máy chủ trả về lỗi.")
        }
        
        do {
            let decodedResponse = try JSONDecoder().decode(MovieListV1Response.self, from: data)
            if let dataContainer = decodedResponse.data {
                return (dataContainer.items, dataContainer.params?.pagination)
            } else {
                throw APIError.serverError(decodedResponse.msg)
            }
        } catch {
            #if DEBUG
            if let decErr = error as? DecodingError {
                let details = decodingDetails(from: decErr)
                print("🧩 DecodingError at \(details.path): \(details.reason)")
                if let underlying = details.underlying { print("↪︎ Underlying: \(underlying)") }
            } else {
                print("🧩 Decode failed: \(error.localizedDescription)")
            }
            #endif
            throw APIError.decodingError(error)
        }
    }
    
    /// Lấy chi tiết phim và tập phim
    func fetchMovieDetail(slug: String) async throws -> MovieDetailResponse {
        guard let url = URL(string: "\(baseURL)/phim/\(slug)") else {
            throw APIError.invalidURL
        }
        
        let start = CFAbsoluteTimeGetCurrent()
        NetworkLogger.logRequest(url)
        let (data, response) = try await URLSession.shared.data(from: url)
        NetworkLogger.logResponse(url, response: response, data: data, error: nil, startTime: start)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            NetworkLogger.logResponse(url, response: response, data: nil, error: APIError.serverError("HTTP status not OK"), startTime: start)
            throw APIError.serverError("Không thể lấy thông tin chi tiết phim.")
        }
        
        do {
            let decodedResponse = try JSONDecoder().decode(MovieDetailResponse.self, from: data)
            if decodedResponse.status {
                return decodedResponse
            } else {
                throw APIError.serverError(decodedResponse.msg)
            }
        } catch {
            #if DEBUG
            if let decErr = error as? DecodingError {
                let details = decodingDetails(from: decErr)
                print("🧩 DecodingError at \(details.path): \(details.reason)")
                if let underlying = details.underlying { print("↪︎ Underlying: \(underlying)") }
            } else {
                print("🧩 Decode failed: \(error.localizedDescription)")
            }
            #endif
            throw APIError.decodingError(error)
        }
    }
    
    /// Tìm kiếm phim theo từ khóa (Format 2)
    func searchMovies(keyword: String, page: Int) async throws -> (movies: [Movie], pagination: Pagination?) {
        guard let encodedKeyword = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/v1/api/tim-kiem?keyword=\(encodedKeyword)&page=\(page)&limit=10") else {
            throw APIError.invalidURL
        }
        
        let start = CFAbsoluteTimeGetCurrent()
        NetworkLogger.logRequest(url)
        let (data, response) = try await URLSession.shared.data(from: url)
        NetworkLogger.logResponse(url, response: response, data: data, error: nil, startTime: start)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            NetworkLogger.logResponse(url, response: response, data: nil, error: APIError.serverError("HTTP status not OK"), startTime: start)
            throw APIError.serverError("Không thể tìm kiếm phim lúc này.")
        }
        
        do {
            let decodedResponse = try JSONDecoder().decode(MovieListV1Response.self, from: data)
            if let dataContainer = decodedResponse.data {
                return (dataContainer.items, dataContainer.params?.pagination)
            } else {
                throw APIError.serverError(decodedResponse.msg)
            }
        } catch {
            #if DEBUG
            if let decErr = error as? DecodingError {
                let details = decodingDetails(from: decErr)
                print("🧩 DecodingError at \(details.path): \(details.reason)")
                if let underlying = details.underlying { print("↪︎ Underlying: \(underlying)") }
            } else {
                print("🧩 Decode failed: \(error.localizedDescription)")
            }
            #endif
            throw APIError.decodingError(error)
        }
    }
    
    /// Lấy danh sách tất cả thể loại
    func fetchAllGenres() async throws -> [Category] {
        guard let url = URL(string: "\(baseURL)/the-loai") else {
            throw APIError.invalidURL
        }
        
        let start = CFAbsoluteTimeGetCurrent()
        NetworkLogger.logRequest(url)
        let (data, response) = try await URLSession.shared.data(from: url)
        NetworkLogger.logResponse(url, response: response, data: data, error: nil, startTime: start)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            NetworkLogger.logResponse(url, response: response, data: nil, error: APIError.serverError("HTTP status not OK"), startTime: start)
            throw APIError.serverError("Không thể tải danh sách thể loại.")
        }
        
        do {
            return try JSONDecoder().decode([Category].self, from: data)
        } catch {
            #if DEBUG
            if let decErr = error as? DecodingError {
                let details = decodingDetails(from: decErr)
                print("🧩 DecodingError at \(details.path): \(details.reason)")
                if let underlying = details.underlying { print("↪︎ Underlying: \(underlying)") }
            } else {
                print("🧩 Decode failed: \(error.localizedDescription)")
            }
            #endif
            throw APIError.decodingError(error)
        }
    }
    
    /// Lấy danh sách tất cả quốc gia
    func fetchAllCountries() async throws -> [Country] {
        guard let url = URL(string: "\(baseURL)/quoc-gia") else {
            throw APIError.invalidURL
        }
        
        let start = CFAbsoluteTimeGetCurrent()
        NetworkLogger.logRequest(url)
        let (data, response) = try await URLSession.shared.data(from: url)
        NetworkLogger.logResponse(url, response: response, data: data, error: nil, startTime: start)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            NetworkLogger.logResponse(url, response: response, data: nil, error: APIError.serverError("HTTP status not OK"), startTime: start)
            throw APIError.serverError("Không thể tải danh sách quốc gia.")
        }
        
        do {
            return try JSONDecoder().decode([Country].self, from: data)
        } catch {
            #if DEBUG
            if let decErr = error as? DecodingError {
                let details = decodingDetails(from: decErr)
                print("🧩 DecodingError at \(details.path): \(details.reason)")
                if let underlying = details.underlying { print("↪︎ Underlying: \(underlying)") }
            } else {
                print("🧩 Decode failed: \(error.localizedDescription)")
            }
            #endif
            throw APIError.decodingError(error)
        }
    }
    
    /// Lấy phim theo thể loại (Format 2)
    func fetchMoviesByGenre(genreSlug: String, page: Int) async throws -> (movies: [Movie], pagination: Pagination?) {
        guard let url = URL(string: "\(baseURL)/v1/api/the-loai/\(genreSlug)?page=\(page)") else {
            throw APIError.invalidURL
        }
        
        let start = CFAbsoluteTimeGetCurrent()
        NetworkLogger.logRequest(url)
        let (data, response) = try await URLSession.shared.data(from: url)
        NetworkLogger.logResponse(url, response: response, data: data, error: nil, startTime: start)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            NetworkLogger.logResponse(url, response: response, data: nil, error: APIError.serverError("HTTP status not OK"), startTime: start)
            throw APIError.serverError("Không thể tải phim theo thể loại.")
        }
        
        do {
            let decodedResponse = try JSONDecoder().decode(MovieListV1Response.self, from: data)
            if let dataContainer = decodedResponse.data {
                return (dataContainer.items, dataContainer.params?.pagination)
            } else {
                throw APIError.serverError(decodedResponse.msg)
            }
        } catch {
            #if DEBUG
            if let decErr = error as? DecodingError {
                let details = decodingDetails(from: decErr)
                print("🧩 DecodingError at \(details.path): \(details.reason)")
                if let underlying = details.underlying { print("↪︎ Underlying: \(underlying)") }
            } else {
                print("🧩 Decode failed: \(error.localizedDescription)")
            }
            #endif
            throw APIError.decodingError(error)
        }
    }
    
    /// Lấy phim theo quốc gia (Format 2)
    func fetchMoviesByCountry(countrySlug: String, page: Int) async throws -> (movies: [Movie], pagination: Pagination?) {
        guard let url = URL(string: "\(baseURL)/v1/api/quoc-gia/\(countrySlug)?page=\(page)") else {
            throw APIError.invalidURL
        }
        
        let start = CFAbsoluteTimeGetCurrent()
        NetworkLogger.logRequest(url)
        let (data, response) = try await URLSession.shared.data(from: url)
        NetworkLogger.logResponse(url, response: response, data: data, error: nil, startTime: start)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            NetworkLogger.logResponse(url, response: response, data: nil, error: APIError.serverError("HTTP status not OK"), startTime: start)
            throw APIError.serverError("Không thể tải phim theo quốc gia.")
        }
        
        do {
            let decodedResponse = try JSONDecoder().decode(MovieListV1Response.self, from: data)
            if let dataContainer = decodedResponse.data {
                return (dataContainer.items, dataContainer.params?.pagination)
            } else {
                throw APIError.serverError(decodedResponse.msg)
            }
        } catch {
            #if DEBUG
            if let decErr = error as? DecodingError {
                let details = decodingDetails(from: decErr)
                print("🧩 DecodingError at \(details.path): \(details.reason)")
                if let underlying = details.underlying { print("↪︎ Underlying: \(underlying)") }
            } else {
                print("🧩 Decode failed: \(error.localizedDescription)")
            }
            #endif
            throw APIError.decodingError(error)
        }
    }
    
    /// Lấy danh sách phim kết hợp bộ lọc (thể loại, quốc gia, năm)
    func fetchFilteredMovies(type: String, categorySlug: String?, countrySlug: String?, year: Int?, page: Int) async throws -> (movies: [Movie], pagination: Pagination?) {
        var urlString = "\(baseURL)/v1/api/danh-sach/\(type)?page=\(page)"
        if let category = categorySlug {
            urlString += "&category=\(category)"
        }
        if let country = countrySlug {
            urlString += "&country=\(country)"
        }
        if let y = year {
            urlString += "&year=\(y)"
        }
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let start = CFAbsoluteTimeGetCurrent()
        NetworkLogger.logRequest(url)
        let (data, response) = try await URLSession.shared.data(from: url)
        NetworkLogger.logResponse(url, response: response, data: data, error: nil, startTime: start)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            NetworkLogger.logResponse(url, response: response, data: nil, error: APIError.serverError("HTTP status not OK"), startTime: start)
            throw APIError.serverError("Không thể tải danh sách phim theo bộ lọc.")
        }
        
        do {
            let decodedResponse = try JSONDecoder().decode(MovieListV1Response.self, from: data)
            if let dataContainer = decodedResponse.data {
                return (dataContainer.items, dataContainer.params?.pagination)
            } else {
                throw APIError.serverError(decodedResponse.msg)
            }
        } catch {
            #if DEBUG
            if let decErr = error as? DecodingError {
                let details = decodingDetails(from: decErr)
                print("🧩 DecodingError at \(details.path): \(details.reason)")
                if let underlying = details.underlying { print("↪︎ Underlying: \(underlying)") }
            } else {
                print("🧩 Decode failed: \(error.localizedDescription)")
            }
            #endif
            throw APIError.decodingError(error)
        }
    }
}

