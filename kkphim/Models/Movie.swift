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

// MARK: - Category Model
struct Category: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let slug: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case idAlternative = "_id"
        case name
        case slug
    }
    
    init(id: String, name: String, slug: String) {
        self.id = id
        self.name = name
        self.slug = slug
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.slug = try container.decode(String.self, forKey: .slug)
        
        if let idVal = try? container.decode(String.self, forKey: .id) {
            self.id = idVal
        } else if let idAltVal = try? container.decode(String.self, forKey: .idAlternative) {
            self.id = idAltVal
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.id,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected 'id' or '_id' for Category"
                )
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(slug, forKey: .slug)
    }
}

// MARK: - Country Model
struct Country: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let slug: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case idAlternative = "_id"
        case name
        case slug
    }
    
    init(id: String, name: String, slug: String) {
        self.id = id
        self.name = name
        self.slug = slug
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.slug = try container.decode(String.self, forKey: .slug)
        
        if let idVal = try? container.decode(String.self, forKey: .id) {
            self.id = idVal
        } else if let idAltVal = try? container.decode(String.self, forKey: .idAlternative) {
            self.id = idAltVal
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.id,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected 'id' or '_id' for Country"
                )
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(slug, forKey: .slug)
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
