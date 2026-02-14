import SwiftUI

struct AvatarView: View {
    let url: URL?
    let initials: String
    let size: CGFloat

    @StateObject private var loader = AvatarLoader()

    init(url: URL?, initials: String, size: CGFloat = 20) {
        self.url = url
        self.initials = initials
        self.size = size
    }

    var body: some View {
        ZStack {
            if let nsImage = loader.image {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholderView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .onAppear {
            loader.load(url: url)
        }
        .onDisappear {
            loader.cancel()
        }
        .onChange(of: url) { newUrl in
            loader.load(url: newUrl)
        }
    }

    private var placeholderView: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.ubPrimary, Color.ubPrimary.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Text(initials)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundColor(.white)
        }
    }
}
