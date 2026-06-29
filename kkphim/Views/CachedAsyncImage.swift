import SwiftUI
import UIKit

struct CachedAsyncImage<Placeholder: View, Failure: View>: View {
    let url: URL?
    let contentMode: ContentMode
    let cornerRadius: CGFloat
    let placeholder: () -> Placeholder
    let failure: () -> Failure

    @State private var uiImage: UIImage?
    @State private var isLoading = false

    init(url: URL?, contentMode: ContentMode = .fill, cornerRadius: CGFloat = 8, @ViewBuilder placeholder: @escaping () -> Placeholder, @ViewBuilder failure: @escaping () -> Failure) {
        self.url = url
        self.contentMode = contentMode
        self.cornerRadius = cornerRadius
        self.placeholder = placeholder
        self.failure = failure
    }

    var body: some View {
        ZStack {
            if let image = uiImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .cornerRadius(cornerRadius)
                    .clipped()
            } else if isLoading {
                placeholder()
            } else {
                placeholder()
                    .task(id: url) {
                        await load()
                    }
            }
        }
    }

    private func load() async {
        guard !isLoading else { return }
        guard let url else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let image = try await ImageLoader.shared.image(from: url)
            self.uiImage = image
        } catch {
            // show failure UI briefly then allow retry on id change
            self.uiImage = nil
        }
    }
}
