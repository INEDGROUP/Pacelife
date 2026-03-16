import SwiftUI
import MapKit
import Supabase

struct CompleteProfileView: View {
    @EnvironmentObject var userManager: UserManager
    @Environment(\.dismiss) var dismiss
    @FocusState private var focusedField: Field?

    enum Field {
        case name, height, weight, city
    }

    @State private var name: String = ""
    @State private var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    @State private var gender: String = ""
    @State private var heightCm: String = ""
    @State private var weightKg: String = ""
    @State private var city: String = ""
    @State private var citySuggestions: [String] = []
    @State private var showCitySuggestions = false
    @State private var isSaving = false
    @State private var appeared = false
    @State private var showDatePicker = false
    @State private var saveSuccess = false

    let genders = [
        ("male", "Male", "figure.stand"),
        ("female", "Female", "figure.stand.dress"),
        ("other", "Other", "person.fill"),
        ("prefer_not_to_say", "Private", "eyeglasses")
    ]

    var completionPercent: Int {
        var count = 0
        if !name.isEmpty { count += 1 }
        if !gender.isEmpty { count += 1 }
        if !heightCm.isEmpty { count += 1 }
        if !weightKg.isEmpty { count += 1 }
        if !city.isEmpty { count += 1 }
        return Int(Double(count) / 5.0 * 100)
    }

    var body: some View {
        ZStack {
            Color.plBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection
                    completionBar
                    nameSection
                    genderSection
                    bodySection
                    citySection
                    saveButton
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 60)
            }
            .onTapGesture {
                focusedField = nil
                showCitySuggestions = false
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Skip") { dismiss() }
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Color.plTextTertiary)
            }
            ToolbarItem(placement: .keyboard) {
                HStack {
                    Spacer()
                    Button("Done") { focusedField = nil }
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.plGreen)
                }
            }
        }
        .onAppear {
            name = userManager.profile?.name ?? ""
            city = userManager.profile?.city ?? ""
            if let h = userManager.profile?.heightCm { heightCm = "\(h)" }
            if let w = userManager.profile?.weightKg { weightKg = String(format: "%.0f", w) }
            if let g = userManager.profile?.gender { gender = g }
            if let dob = userManager.profile?.dateOfBirth { dateOfBirth = dob }
            withAnimation(PLTheme.springSmooth) { appeared = true }
        }
    }

    var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.plGreen.opacity(0.2), Color(hex: "6B8FFF").opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
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
                Text(name.prefix(1).uppercased().isEmpty ? "?" : name.prefix(1).uppercased())
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.plGreen, Color(hex: "6B8FFF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.7)
            .animation(PLTheme.springSmooth.delay(0.1), value: appeared)

            VStack(spacing: 4) {
                Text("Complete your profile")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.plTextPrimary)
                Text("Better data means smarter AI insights")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Color.plTextTertiary)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .animation(PLTheme.springSmooth.delay(0.15), value: appeared)
        }
    }

    var completionBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Profile completion")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Color.plTextTertiary)
                Spacer()
                Text("\(completionPercent)%")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(completionPercent == 100 ? Color.plGreen : Color.plAmber)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.plBgTertiary)
                        .frame(height: 6)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: completionPercent == 100
                                    ? [Color.plGreen, Color(hex: "00C875")]
                                    : [Color.plAmber, Color.plGreen],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geo.size.width * CGFloat(completionPercent) / 100, 4), height: 6)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: completionPercent)
                }
            }
            .frame(height: 6)
        }
        .plCard()
        .opacity(appeared ? 1 : 0)
        .animation(PLTheme.springSmooth.delay(0.2), value: appeared)
    }

    var nameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "person.fill", title: "Name", color: Color.plGreen)
            HStack {
                Image(systemName: "person")
                    .font(.system(size: 15))
                    .foregroundStyle(focusedField == .name ? Color.plGreen : Color.plTextTertiary)
                    .frame(width: 20)
                TextField("Your full name", text: $name)
                    .font(.system(size: 16, design: .rounded))
                    .foregroundStyle(Color.plTextPrimary)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .height }
            }
            .padding(16)
            .background(Color.plBgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: PLRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: PLRadius.lg)
                    .strokeBorder(focusedField == .name ? Color.plGreen.opacity(0.5) : Color.plBorder, lineWidth: focusedField == .name ? 1 : 0.5)
            )
            .animation(.easeInOut(duration: 0.2), value: focusedField)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(PLTheme.springSmooth.delay(0.25), value: appeared)
    }

    var genderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "person.2.fill", title: "Gender", color: Color(hex: "6B8FFF"))
            HStack(spacing: 8) {
                ForEach(genders, id: \.0) { value, label, icon in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                            gender = value
                        }
                        focusedField = nil
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: icon)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(
                                    gender == value
                                    ? LinearGradient(colors: [Color(hex: "6B8FFF"), Color(hex: "4A6FF5")], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    : LinearGradient(colors: [Color.plTextTertiary, Color.plTextTertiary], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .shadow(color: gender == value ? Color(hex: "6B8FFF").opacity(0.3) : .clear, radius: 6)
                            Text(label)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(gender == value ? Color(hex: "6B8FFF") : Color.plTextTertiary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(gender == value ? Color(hex: "6B8FFF").opacity(0.1) : Color.plBgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: PLRadius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: PLRadius.md)
                                .strokeBorder(gender == value ? Color(hex: "6B8FFF").opacity(0.3) : Color.plBorder, lineWidth: gender == value ? 1 : 0.5)
                        )
                        .scaleEffect(gender == value ? 1.02 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: gender)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(PLTheme.springSmooth.delay(0.3), value: appeared)
    }

    var bodySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "ruler.fill", title: "Body measurements", color: Color.plAmber)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Height")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Color.plTextTertiary)
                    HStack {
                        TextField("175", text: $heightCm)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.plTextPrimary)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .height)
                            .onChange(of: heightCm) { val in
                                let filtered = val.filter { $0.isNumber }
                                if filtered != val { heightCm = filtered }
                                if filtered.count > 3 { heightCm = String(filtered.prefix(3)) }
                            }
                        Text("cm")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(Color.plTextTertiary)
                    }
                    .padding(14)
                    .background(Color.plBgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: PLRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: PLRadius.md)
                            .strokeBorder(focusedField == .height ? Color.plAmber.opacity(0.5) : Color.plBorder, lineWidth: focusedField == .height ? 1 : 0.5)
                    )
                    .animation(.easeInOut(duration: 0.2), value: focusedField)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Weight")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Color.plTextTertiary)
                    HStack {
                        TextField("70", text: $weightKg)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.plTextPrimary)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .weight)
                            .onChange(of: weightKg) { val in
                                let filtered = val.filter { $0.isNumber || $0 == "." }
                                if filtered != val { weightKg = filtered }
                            }
                        Text("kg")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(Color.plTextTertiary)
                    }
                    .padding(14)
                    .background(Color.plBgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: PLRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: PLRadius.md)
                            .strokeBorder(focusedField == .weight ? Color.plAmber.opacity(0.5) : Color.plBorder, lineWidth: focusedField == .weight ? 1 : 0.5)
                    )
                    .animation(.easeInOut(duration: 0.2), value: focusedField)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Date of birth")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Color.plTextTertiary)
                Button(action: {
                    focusedField = nil
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showDatePicker.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.plAmber)
                        Text(dateOfBirth.formatted(.dateTime.day().month(.wide).year()))
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(Color.plTextPrimary)
                        Spacer()
                        Image(systemName: showDatePicker ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.plTextTertiary)
                    }
                    .padding(14)
                    .background(Color.plBgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: PLRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: PLRadius.md)
                            .strokeBorder(showDatePicker ? Color.plAmber.opacity(0.5) : Color.plBorder, lineWidth: showDatePicker ? 1 : 0.5)
                    )
                }
                .buttonStyle(.plain)

                if showDatePicker {
                    DatePicker(
                        "",
                        selection: $dateOfBirth,
                        in: ...Calendar.current.date(byAdding: .year, value: -10, to: Date())!,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.wheel)
                    .colorScheme(.dark)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(PLTheme.springSmooth.delay(0.35), value: appeared)
    }

    var citySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "building.2.fill", title: "City", color: Color.plBlue)

            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "mappin")
                        .font(.system(size: 15))
                        .foregroundStyle(focusedField == .city ? Color.plBlue : Color.plTextTertiary)
                        .frame(width: 20)
                    TextField("London", text: $city)
                        .font(.system(size: 16, design: .rounded))
                        .foregroundStyle(Color.plTextPrimary)
                        .focused($focusedField, equals: .city)
                        .autocorrectionDisabled()
                        .onChange(of: city) { value in
                            searchCity(query: value)
                        }
                    if !city.isEmpty {
                        Button(action: {
                            city = ""
                            citySuggestions = []
                            showCitySuggestions = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.plTextTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .background(Color.plBgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: PLRadius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: PLRadius.lg)
                        .strokeBorder(focusedField == .city ? Color.plBlue.opacity(0.5) : Color.plBorder, lineWidth: focusedField == .city ? 1 : 0.5)
                )
                .animation(.easeInOut(duration: 0.2), value: focusedField)

                if showCitySuggestions && !citySuggestions.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(citySuggestions, id: \.self) { suggestion in
                            Button(action: {
                                city = suggestion
                                citySuggestions = []
                                showCitySuggestions = false
                                focusedField = nil
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.plBlue)
                                    Text(suggestion)
                                        .font(.system(size: 14, design: .rounded))
                                        .foregroundStyle(Color.plTextPrimary)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)

                            if suggestion != citySuggestions.last {
                                Divider()
                                    .background(Color.plBorder)
                                    .padding(.leading, 44)
                            }
                        }
                    }
                    .background(Color.plBgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: PLRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: PLRadius.lg)
                            .strokeBorder(Color.plBlue.opacity(0.3), lineWidth: 0.5)
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(PLTheme.springSmooth.delay(0.4), value: appeared)
    }

    var saveButton: some View {
        VStack(spacing: 12) {
            if saveSuccess {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.plGreen)
                    Text("Profile saved!")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(Color.plGreen)
                }
                .transition(.scale.combined(with: .opacity))
            }

            PLPrimaryButton(
                title: isSaving ? "Saving..." : "Save Profile",
                icon: isSaving ? "hourglass" : "checkmark"
            ) {
                focusedField = nil
                Task { await saveProfile() }
            }
            .disabled(isSaving)

            Text("You can update this anytime in your profile")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Color.plTextTertiary)
        }
        .opacity(appeared ? 1 : 0)
        .animation(PLTheme.springSmooth.delay(0.45), value: appeared)
    }

    private func searchCity(query: String) {
        guard query.count >= 2 else {
            citySuggestions = []
            showCitySuggestions = false
            return
        }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .address
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let response = response, error == nil else { return }
            let cities = response.mapItems
                .compactMap { item -> String? in
                    guard let city = item.placemark.locality,
                          let country = item.placemark.country else { return nil }
                    return "\(city), \(country)"
                }
            let unique = Array(NSOrderedSet(array: cities)) as? [String] ?? []
            DispatchQueue.main.async {
                citySuggestions = Array(unique.prefix(5))
                showCitySuggestions = !citySuggestions.isEmpty
            }
        }
    }

    private func saveProfile() async {
        isSaving = true
        guard let userId = AuthService.shared.currentUser?.id else {
            isSaving = false
            return
        }
        let client = SupabaseManager.shared.client
        var updates: [String: AnyJSON] = [
            "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
        ]
        if !name.isEmpty { updates["name"] = .string(name) }
        if !gender.isEmpty { updates["gender"] = .string(gender) }
        if !city.isEmpty { updates["city"] = .string(city) }
        if let h = Int(heightCm) { updates["height_cm"] = .double(Double(h)) }
        if let w = Double(weightKg) { updates["weight_kg"] = .double(w) }
        let dobFormatter = ISO8601DateFormatter()
        dobFormatter.formatOptions = [.withFullDate]
        updates["date_of_birth"] = .string(dobFormatter.string(from: dateOfBirth))
        do {
            try await client
                .from("profiles")
                .update(updates)
                .eq("id", value: userId.supabaseString)
                .execute()
            await userManager.loadUserData(userId: userId)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                saveSuccess = true
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            try await Task.sleep(nanoseconds: 1_200_000_000)
            dismiss()
        } catch {
            print("Save profile error: \(error)")
        }
        isSaving = false
    }
}

struct SectionHeader: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.plTextSecondary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
    }
}
