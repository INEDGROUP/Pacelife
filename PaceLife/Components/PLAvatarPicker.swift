import SwiftUI
import PhotosUI

struct PLAvatarPicker: View {
    @EnvironmentObject var userManager: UserManager
    @State private var selectedItem: PhotosPickerItem?
    @State private var showOptions = false
    @State private var isUploading = false
    @State private var uploadError: String?
    let size: CGFloat

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            PLAvatarView(
                url: userManager.profile?.avatarUrl,
                name: userManager.firstName,
                size: size
            )

            if isUploading {
                Circle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: size, height: size)
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.9)
            }

            PhotosPicker(
                selection: $selectedItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                ZStack {
                    Circle()
                        .fill(Color.plGreen)
                        .frame(width: size * 0.32, height: size * 0.32)
                        .shadow(color: Color.plGreen.opacity(0.4), radius: 4)
                    Image(systemName: isUploading ? "hourglass" : "camera.fill")
                        .font(.system(size: size * 0.14, weight: .semibold))
                        .foregroundStyle(Color.plBg)
                }
            }
            .disabled(isUploading)
            .buttonStyle(.plain)
        }
        .onChange(of: selectedItem) { item in
            guard let item = item else { return }
            Task { await uploadAvatar(item: item) }
        }
        .alert("Upload failed", isPresented: .constant(uploadError != nil)) {
            Button("OK") { uploadError = nil }
        } message: {
            Text(uploadError ?? "")
        }
    }

    private func uploadAvatar(item: PhotosPickerItem) async {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        isUploading = true
        uploadError = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                uploadError = "Could not load image data"
                isUploading = false
                return
            }
            guard let uiImage = UIImage(data: data) else {
                uploadError = "Invalid image format"
                isUploading = false
                return
            }
            let targetSize = CGSize(width: 400, height: 400)
            let resized = resizeImage(uiImage, targetSize: targetSize)
            guard let compressed = resized.jpegData(compressionQuality: 0.75) else {
                uploadError = "Could not compress image"
                isUploading = false
                return
            }
            print("Avatar: uploading \(compressed.count / 1024)KB for user \(userId.supabaseString)")
            _ = try await userManager.uploadAvatar(imageData: compressed, userId: userId)
            await userManager.loadUserData(userId: userId)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            print("Avatar: upload successful")
        } catch {
            uploadError = "Upload failed: \(error.localizedDescription)"
            print("Avatar upload error: \(error)")
        }
        selectedItem = nil
        isUploading = false
    }

    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let ratio = min(widthRatio, heightRatio)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
