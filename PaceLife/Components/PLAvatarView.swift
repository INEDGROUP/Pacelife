import SwiftUI

struct PLAvatarView: View {
    let url: String?
    let name: String
    let size: CGFloat
    @State private var image: UIImage?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.plGreen.opacity(0.2), Color(hex: "6B8FFF").opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.plGreen.opacity(0.4), Color(hex: "6B8FFF").opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )

            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Text(name.prefix(1).uppercased().isEmpty ? "?" : name.prefix(1).uppercased())
                    .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.plGreen, Color(hex: "6B8FFF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            if isLoading {
                Circle()
                    .fill(Color.black.opacity(0.3))
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.8)
            }
        }
        .frame(width: size, height: size)
        .task {
            await loadImage()
        }
        .onChange(of: url) { _ in
            image = nil
            Task { await loadImage() }
        }
    }

    private func loadImage() async {
        guard let urlString = url,
              !urlString.isEmpty,
              let url = URL(string: urlString) else { return }
        isLoading = true
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let uiImage = UIImage(data: data) {
                image = uiImage
            }
        } catch {
            print("Avatar load error: \(error)")
        }
        isLoading = false
    }
}
