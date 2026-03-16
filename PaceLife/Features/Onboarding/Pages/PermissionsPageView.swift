import SwiftUI
import CoreLocation
import HealthKit

struct PermissionsPageView: View {
    let onNext: () -> Void
    @State private var appeared = false
    @State private var locationGranted = false
    @State private var healthGranted = false
    @StateObject private var locationManager = LocationManager()

    var allGranted: Bool { locationGranted && healthGranted }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Text("Two quick\npermissions")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.plTextPrimary)
                        .multilineTextAlignment(.center)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 24)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: appeared)

                    Text("PaceLife works best with access\nto your location and health data")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.plTextTertiary)
                        .multilineTextAlignment(.center)
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: appeared)
                }

                VStack(spacing: 12) {
                    PermissionRow(
                        icon: "location.fill",
                        color: .plBlue,
                        title: "Location",
                        subtitle: "To build routes around you",
                        isGranted: locationGranted
                    ) {
                        locationManager.requestPermission()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                locationGranted = true
                            }
                        }
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.3), value: appeared)

                    PermissionRow(
                        icon: "heart.fill",
                        color: .plRed,
                        title: "Health",
                        subtitle: "To track sleep and activity",
                        isGranted: healthGranted
                    ) {
                        requestHealthPermission()
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.4), value: appeared)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 12) {
                PLPrimaryButton(title: allGranted ? "All set — Continue" : "Continue", icon: "arrow.right") {
                    onNext()
                }

                Button("Skip for now") { onNext() }
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Color.plTextTertiary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: appeared)
        }
        .onAppear { appeared = true }
    }

    private func requestHealthPermission() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let store = HKHealthStore()
        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
        store.requestAuthorization(toShare: nil, read: readTypes) { success, _ in
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    self.healthGranted = success
                }
            }
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(color.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.plTextPrimary)
                Text(subtitle)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Color.plTextTertiary)
            }

            Spacer()

            Button(action: action) {
                ZStack {
                    if isGranted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.plGreen)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text("Allow")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.plBg)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.plTextPrimary)
                            .clipShape(Capsule())
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isGranted)
            }
            .disabled(isGranted)
        }
        .padding(16)
        .background(Color.plBgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: PLRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: PLRadius.lg)
                .strokeBorder(Color.plBorder, lineWidth: 0.5)
        )
    }
}
