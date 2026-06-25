//
//  Movie.swift
//  kkphim
//
//  Created by Antigravity on 25/6/26.
//

import Foundation

// MARK: - API Response for Movie List
struct MovieResponse: Codable {
    let status: Bool
    let msg: String
    let items: [Movie]
    let pagination: Pagination?
}

// MARK: - Pagination Info
struct Pagination: Codable {
    let totalItems: Int
    let totalItemsPerPage: Int
    let currentPage: Int
    let totalPages: Int
}

// MARK: - Basic Movie Model
struct Movie: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let slug: String
    let originName: String
    let posterUrl: String
    let thumbUrl: String
    let year: Int

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case slug
        case originName = "origin_name"
        case posterUrl = "poster_url"
        case thumbUrl = "thumb_url"
        case year
    }
    
    var fullPosterURL: URL? {
        cleanAndBuildURL(posterUrl)
    }
    
    var fullThumbURL: URL? {
        cleanAndBuildURL(thumbUrl)
    }
    
    private func cleanAndBuildURL(_ urlString: String) -> URL? {
        let cleaned = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.lowercased().hasPrefix("http") {
            return URL(string: cleaned)
        } else {
            return URL(string: "https://phimimg.com/\(cleaned)")
        }
    }
}

// MARK: - API Response for Movie Detail
struct MovieDetailResponse: Codable {
    let status: Bool
    let msg: String
    let movie: MovieDetail
    let episodes: [EpisodeServer]
}

// MARK: - Detailed Movie Model
struct MovieDetail: Codable, Identifiable {
    let id: String
    let name: String
    let slug: String
    let originName: String
    let content: String
    let type: String
    let status: String
    let posterUrl: String
    let thumbUrl: String
    let time: String
    let episodeCurrent: String
    let episodeTotal: String
    let quality: String
    let lang: String
    let year: Int
    let view: Int
    let actor: [String]
    let director: [String]
    let category: [Category]
    let country: [Country]

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, slug, content, type, status, time, quality, lang, year, view, actor, director, category, country
        case originName = "origin_name"
        case posterUrl = "poster_url"
        case thumbUrl = "thumb_url"
        case episodeCurrent = "episode_current"
        case episodeTotal = "episode_total"
    }
    
    var fullPosterURL: URL? {
        cleanAndBuildURL(posterUrl)
    }
    
    var fullThumbURL: URL? {
        cleanAndBuildURL(thumbUrl)
    }
    
    private func cleanAndBuildURL(_ urlString: String) -> URL? {
        let cleaned = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.lowercased().hasPrefix("http") {
            return URL(string: cleaned)
        } else {
            return URL(string: "https://phimimg.com/\(cleaned)")
        }
    }
}

// MARK: - Category Model
struct Category: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let slug: String
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case slug
    }
}

// MARK: - Country Model
struct Country: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let slug: String
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case slug
    }
}

// MARK: - Episode Server Model
struct EpisodeServer: Codable, Hashable {
    let serverName: String
    let serverData: [Episode]

    enum CodingKeys: String, CodingKey {
        case serverName = "server_name"
        case serverData = "server_data"
    }
}

// MARK: - Episode Model
struct Episode: Codable, Identifiable, Hashable {
    var id: String { slug + "_" + linkM3u8 }
    let name: String
    let slug: String
    let filename: String
    let linkEmbed: String
    let linkM3u8: String

    enum CodingKeys: String, CodingKey {
        case name, slug, filename
        case linkEmbed = "link_embed"
        case linkM3u8 = "link_m3u8"
    }
}

// MARK: - API V1 Response wrappers (for categories and search)
struct MovieListV1Response: Codable {
    let status: StringOrBool
    let msg: String
    let data: MovieListV1Data?
}

struct MovieListV1Data: Codable {
    let items: [Movie]
    let params: MovieListV1Params?
}

struct MovieListV1Params: Codable {
    let pagination: Pagination?
}

enum StringOrBool: Codable {
    case string(String)
    case bool(Bool)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let boolVal = try? container.decode(Bool.self) {
            self = .bool(boolVal)
            return
        }
        if let stringVal = try? container.decode(String.self) {
            self = .string(stringVal)
            return
        }
        throw DecodingError.typeMismatch(
            StringOrBool.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected String or Bool"
            )
        )
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let str):
            try container.encode(str)
        case .bool(let b):
            try container.encode(b)
        }
    }
}

