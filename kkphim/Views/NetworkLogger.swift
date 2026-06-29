import Foundation

enum NetworkLogger {
    static func logRequest(_ url: URL, method: String = "GET") {
        #if DEBUG
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        print("\n================ REQUEST ================")
        print("➡️ Method: \(method)")
        print("🌐 URL: \(url.absoluteString)")
        if let host = components?.host { print("🔸 Host: \(host)") }
        if let path = components?.path { print("🔹 Path: \(path)") }
        if let queryItems = components?.queryItems, !queryItems.isEmpty {
            print("🔎 Query Params:")
            for item in queryItems {
                print("   • \(item.name)=\(item.value ?? "")")
            }
        }
        print("========================================\n")
        #endif
    }

    static func logResponse(_ url: URL, response: URLResponse?, data: Data?, error: Error?, startTime: CFAbsoluteTime) {
        #if DEBUG
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        print("\n================ RESPONSE ================")
        print("⏱️ Duration: \(Int(elapsed)) ms")
        print("🌐 URL: \(url.absoluteString)")
        if let http = response as? HTTPURLResponse {
            print("📡 Status: \(http.statusCode)")
            if !http.allHeaderFields.isEmpty {
                print("📬 Headers:")
                for (key, value) in http.allHeaderFields {
                    print("   • \(key): \(value)")
                }
            }
        } else {
            print("📡 Status: -- (non-HTTP)")
        }
        if let error = error {
            print("❌ Error: \(error.localizedDescription)")
        }
        if let data = data {
            print("📦 Data size: \(data.count) bytes")
            if let pretty = prettyPrinted(data: data) {
                print("📄 Body (pretty):\n\(pretty)")
            } else if let text = String(data: data, encoding: .utf8) {
                print("📄 Body (utf8):\n\(text)")
            } else {
                print("📄 Body: <non-textual data>")
            }
        } else {
            print("📦 Data: nil")
        }
        print("==========================================\n")
        #endif
    }

    private static func prettyPrinted(data: Data) -> String? {
        // Try JSON pretty print
        if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
           JSONSerialization.isValidJSONObject(jsonObject),
           let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            return prettyString
        }
        return nil
    }
}
