import SwiftUI
import MapKit

struct MapView: View {
    @EnvironmentObject var userManager: UserManager
    @StateObject private var viewModel = MapViewModel()
    @State private var selectedSpot: Spot?
    @State private var selectedRoute: PLRoute?
    @State private var showAddSpot = false
    @State private var showAllItems = false
    @Namespace private var mapNamespace

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $viewModel.cameraPosition) {
                UserAnnotation()

                if viewModel.activeLayer == .spots || viewModel.activeLayer == .all {
                    ForEach(viewModel.spots) { spot in
                        Annotation(spot.title, coordinate: spot.coordinate) {
                            SpotPin(spot: spot, isSelected: selectedSpot?.id == spot.id)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                        selectedSpot = selectedSpot?.id == spot.id ? nil : spot
                                        selectedRoute = nil
                                    }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                        }
                    }
                }

                if viewModel.activeLayer == .routes || viewModel.activeLayer == .all {
                    ForEach(viewModel.routes) { route in
                        if route.coordinates.count > 1 {
                            MapPolyline(coordinates: route.coordinates.map {
                                CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1])
                            })
                            .stroke(
                                selectedRoute?.id == route.id
                                ? Color.plAmber.opacity(0.95)
                                : Color.plGreen.opacity(0.85),
                                lineWidth: selectedRoute?.id == route.id ? 5 : 3.5
                            )
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .safeAreaPadding(.top, 120)
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation {
                    selectedSpot = nil
                    selectedRoute = nil
                }
            }

            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    layerSwitcher
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if viewModel.isRecording {
                        recordingBadge
                            .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .topTrailing)))
                    }
                }
                .padding(.top, 100)
                .padding(.horizontal, 16)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.isRecording)

                Spacer()

                if let spot = selectedSpot {
                    SpotDetailSheet(
                        spot: spot,
                        onDelete: {
                            Task {
                                await viewModel.deleteSpot(spot)
                                selectedSpot = nil
                            }
                        },
                        onDismiss: {
                            withAnimation { selectedSpot = nil }
                        },
                        onRename: { newTitle in
                            Task { await viewModel.renameSpot(spot, title: newTitle) }
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 110)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if let route = selectedRoute {
                    RouteDetailSheet(
                        route: route,
                        onDelete: {
                            Task {
                                await viewModel.deleteRoute(route)
                                selectedRoute = nil
                            }
                        },
                        onDismiss: {
                            withAnimation { selectedRoute = nil }
                        },
                        onRename: { newTitle in
                            Task { await viewModel.renameRoute(route, title: newTitle) }
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 110)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    bottomBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 110)
                }
            }
        }
        .sheet(isPresented: $showAddSpot) {
            AddSpotSheet(isPresented: $showAddSpot) { title, category, notes in
                Task { await viewModel.addSpot(title: title, category: category, notes: notes) }
            }
        }
        .sheet(isPresented: $showAllItems) {
            AllItemsSheet(viewModel: viewModel, isPresented: $showAllItems)
        }
        .task {
            await viewModel.loadData()
            viewModel.startLocationTracking()
        }
        .onReceive(NotificationCenter.default.publisher(for: .saveRouteAction)) { _ in
            Task { await viewModel.stopRecording() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .discardRouteAction)) { _ in
            viewModel.discardRecording()
        }
        .onChange(of: showAddSpot) { show in
            if !show { Task { await viewModel.loadData() } }
        }
    }

    var layerSwitcher: some View {
        HStack(spacing: 6) {
            ForEach(MapViewModel.MapLayer.allCases, id: \.self) { layer in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.activeLayer = layer
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: layer.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(layer.title)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                        Text("\(layer == .spots ? viewModel.spots.count : layer == .routes ? viewModel.routes.count : viewModel.spots.count + viewModel.routes.count)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(viewModel.activeLayer == layer ? 0.25 : 0.1))
                            .clipShape(Capsule())
                            .frame(minWidth: 16)
                    }
                    .foregroundStyle(viewModel.activeLayer == layer ? Color.plBg : Color.white.opacity(0.85))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(height: 34)
                    .background(viewModel.activeLayer == layer ? Color.plGreen : Color.black.opacity(0.55))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(viewModel.activeLayer == layer ? Color.clear : Color.white.opacity(0.15), lineWidth: 0.5)
                    )
                    .shadow(color: viewModel.activeLayer == layer ? Color.plGreen.opacity(0.35) : .clear, radius: 8)
                }
                .buttonStyle(.plain)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.activeLayer)
            }
        }
        .fixedSize()
    }

    var recordingBadge: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.plRed)
                    .frame(width: 7, height: 7)
                    .shadow(color: Color.plRed.opacity(0.6), radius: 4)
                Text(viewModel.isPaused ? "PAUSED" : "REC")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(viewModel.isPaused ? Color.plAmber : Color.plRed)
                Text(viewModel.formattedDuration)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white)
            }
            HStack(spacing: 8) {
                HStack(spacing: 3) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.plGreen)
                    Text(viewModel.formattedDistance)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white)
                }
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.plAmber)
                    Text("\(viewModel.estimatedCalories)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white)
                }
            }
            if viewModel.autoStopWarning {
                Text("Auto-stop in 1 min")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(Color.plAmber)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(viewModel.isPaused ? Color.plAmber.opacity(0.4) : Color.plRed.opacity(0.4), lineWidth: 0.5)
        )
        .fixedSize()
    }

    var bottomBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    if viewModel.spots.count > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.plGreen)
                            Text("\(viewModel.spots.count)")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.plTextSecondary)
                        }
                    }
                    if viewModel.routes.count > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "figure.walk")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.plBlue)
                            Text("\(viewModel.routes.count)")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.plTextSecondary)
                        }
                    }
                    if viewModel.spots.count == 0 && viewModel.routes.count == 0 {
                        Text("Your city awaits")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Color.plTextTertiary)
                    }
                }
                Text("Your map")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.plTextPrimary)
            }

            Spacer()

            if (viewModel.spots.count > 0 || viewModel.routes.count > 0) && !viewModel.isRecording {
                Button(action: { showAllItems = true }) {
                    Text("See all")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.plGreen)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.plGreen.opacity(0.1))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color.plGreen.opacity(0.2), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .fixedSize()
            }

            if viewModel.isRecording {
                HStack(spacing: 8) {
                    Button(action: {
                        if viewModel.isPaused { viewModel.resumeRecording() }
                        else { viewModel.pauseRecording() }
                    }) {
                        Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .frame(width: 42, height: 42)
                            .background(Color.plAmber.opacity(0.9))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        Task { await viewModel.stopRecording() }
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Save")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(Color.plGreen)
                        .clipShape(Capsule())
                        .fixedSize()
                    }
                    .buttonStyle(.plain)

                    Button(action: { viewModel.discardRecording() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.plRed)
                            .frame(width: 42, height: 42)
                            .background(Color.plRed.opacity(0.1))
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(Color.plRed.opacity(0.2), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
                .fixedSize()
            } else {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.startRecording()
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 13))
                        Text("Record")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Color.plBg)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(Color.plGreen)
                    .clipShape(Capsule())
                    .shadow(color: Color.plGreen.opacity(0.4), radius: 8)
                }
                .buttonStyle(.plain)
                .fixedSize()
            }

            Button(action: { showAddSpot = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.plTextPrimary)
                    .frame(width: 42, height: 42)
                    .background(Color.plBgSecondary)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Color.plBorder, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 8)
    }
}

// MARK: - RouteDetailSheet

struct RouteDetailSheet: View {
    let route: PLRoute
    let onDelete: () -> Void
    let onDismiss: () -> Void
    let onRename: (String) -> Void
    @State private var isEditing = false
    @State private var editTitle = ""
    @FocusState private var titleFocused: Bool

    var intensityColor: Color {
        switch route.intensity {
        case "high": return .plRed
        case "medium": return .plAmber
        default: return .plGreen
        }
    }

    var intensityIcon: String {
        switch route.intensity {
        case "high": return "figure.run"
        default: return "figure.walk"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [intensityColor.opacity(0.3), intensityColor.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    Image(systemName: intensityIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(intensityColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if isEditing {
                        TextField("Route name", text: $editTitle)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.plTextPrimary)
                            .focused($titleFocused)
                            .onSubmit {
                                if !editTitle.isEmpty { onRename(editTitle) }
                                isEditing = false
                            }
                    } else {
                        Text(route.title)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.plTextPrimary)
                    }

                    HStack(spacing: 6) {
                        if let dist = route.distanceKm {
                            Text(String(format: "%.2f km", dist))
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(intensityColor)
                        }
                        if let dur = route.durationMinutes, dur > 0 {
                            Text("·").foregroundStyle(Color.plTextTertiary)
                            Text("\(dur) min")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Color.plTextTertiary)
                        }
                        if let intensity = route.intensity {
                            Text("·").foregroundStyle(Color.plTextTertiary)
                            Text(intensity)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(intensityColor)
                        }
                    }

                    Text(route.createdAt.formatted(.dateTime.day().month(.wide).year()))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Color.plTextTertiary)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.plTextTertiary)
                }
            }

            HStack(spacing: 10) {
                Button(action: {
                    if isEditing {
                        if !editTitle.isEmpty { onRename(editTitle) }
                        isEditing = false
                    } else {
                        editTitle = route.title
                        isEditing = true
                        titleFocused = true
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isEditing ? "checkmark" : "pencil")
                            .font(.system(size: 13))
                        Text(isEditing ? "Save name" : "Rename")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Color.plBg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.plBlue)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.plRed)
                        .frame(width: 44, height: 44)
                        .background(Color.plRed.opacity(0.1))
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Color.plRed.opacity(0.2), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 8)
    }
}

// MARK: - SpotDetailSheet

struct SpotDetailSheet: View {
    let spot: Spot
    let onDelete: () -> Void
    let onDismiss: () -> Void
    let onRename: (String) -> Void
    @State private var isEditing = false
    @State private var editTitle = ""
    @FocusState private var titleFocused: Bool

    var category: SpotCategory { SpotCategory.from(spot.category) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: category.colors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .shadow(color: category.colors[0].opacity(0.3), radius: 8)
                    Image(systemName: category.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if isEditing {
                        TextField("Spot name", text: $editTitle)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.plTextPrimary)
                            .focused($titleFocused)
                            .onSubmit {
                                if !editTitle.isEmpty { onRename(editTitle) }
                                isEditing = false
                            }
                    } else {
                        Text(spot.title)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.plTextPrimary)
                    }
                    HStack(spacing: 4) {
                        Text(category.title)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(category.colors[0])
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(category.colors[0].opacity(0.12))
                            .clipShape(Capsule())
                        Text(spot.createdAt.formatted(.dateTime.day().month(.abbreviated)))
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Color.plTextTertiary)
                    }
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.plTextTertiary)
                }
            }

            if let notes = spot.notes, !notes.isEmpty, !isEditing {
                Text(notes)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Color.plTextSecondary)
                    .lineSpacing(3)
                    .padding(12)
                    .background(Color.plBgTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: PLRadius.md))
            }

            HStack(spacing: 10) {
                Button(action: {
                    let url = URL(string: "maps://?daddr=\(spot.latitude),\(spot.longitude)")!
                    UIApplication.shared.open(url)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                            .font(.system(size: 15))
                        Text("Navigate")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Color.plBg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(colors: category.colors, startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
                    .shadow(color: category.colors[0].opacity(0.3), radius: 8)
                }
                .buttonStyle(.plain)

                Button(action: {
                    if isEditing {
                        if !editTitle.isEmpty { onRename(editTitle) }
                        isEditing = false
                    } else {
                        editTitle = spot.title
                        isEditing = true
                        titleFocused = true
                    }
                }) {
                    Image(systemName: isEditing ? "checkmark" : "pencil")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.plBlue)
                        .frame(width: 44, height: 44)
                        .background(Color.plBlue.opacity(0.1))
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Color.plBlue.opacity(0.2), lineWidth: 0.5))
                }
                .buttonStyle(.plain)

                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.plRed)
                        .frame(width: 44, height: 44)
                        .background(Color.plRed.opacity(0.1))
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Color.plRed.opacity(0.2), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 8)
    }
}

// MARK: - AllItemsSheet

struct AllItemsSheet: View {
    @ObservedObject var viewModel: MapViewModel
    @Binding var isPresented: Bool
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            Color.plBg.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text("Your map")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.plTextPrimary)
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.plTextTertiary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)

                Picker("", selection: $selectedTab) {
                    Text("Spots (\(viewModel.spots.count))").tag(0)
                    Text("Routes (\(viewModel.routes.count))").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                if selectedTab == 0 {
                    if viewModel.spots.isEmpty {
                        emptyState(
                            icon: "mappin",
                            title: "No spots yet",
                            subtitle: "Tap + on the map to save your favourite places"
                        )
                    } else {
                        List {
                            ForEach(viewModel.spots) { spot in
                                SpotListRow(spot: spot)
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    let spot = viewModel.spots[index]
                                    Task { await viewModel.deleteSpot(spot) }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                } else {
                    if viewModel.routes.isEmpty {
                        emptyState(
                            icon: "figure.walk",
                            title: "No routes yet",
                            subtitle: "Tap Record on the map to start recording a route"
                        )
                    } else {
                        List {
                            ForEach(viewModel.routes) { route in
                                RouteListRow(route: route)
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    let route = viewModel.routes[index]
                                    Task { await viewModel.deleteRoute(route) }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
        }
    }

    func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(Color.plTextTertiary)
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.plTextPrimary)
            Text(subtitle)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Color.plTextTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}

// MARK: - SpotListRow

struct SpotListRow: View {
    let spot: Spot
    var category: SpotCategory { SpotCategory.from(spot.category) }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: category.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 40, height: 40)
                Image(systemName: category.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(spot.title)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.plTextPrimary)
                HStack(spacing: 6) {
                    Text(category.title)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(category.colors[0])
                    Text("·").foregroundStyle(Color.plTextTertiary)
                    Text(spot.createdAt.formatted(.dateTime.day().month(.abbreviated)))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Color.plTextTertiary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.plBgSecondary)
        .listRowSeparatorTint(Color.plBorder)
    }
}

// MARK: - RouteListRow

struct RouteListRow: View {
    let route: PLRoute

    var intensityColor: Color {
        switch route.intensity {
        case "high": return .plRed
        case "medium": return .plAmber
        default: return .plGreen
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(intensityColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: "figure.walk")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(intensityColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(route.title)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.plTextPrimary)
                HStack(spacing: 6) {
                    if let dist = route.distanceKm {
                        Text(String(format: "%.2f km", dist))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(intensityColor)
                    }
                    if let dur = route.durationMinutes, dur > 0 {
                        Text("·").foregroundStyle(Color.plTextTertiary)
                        Text("\(dur) min")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Color.plTextTertiary)
                    }
                    Text("·").foregroundStyle(Color.plTextTertiary)
                    Text(route.createdAt.formatted(.dateTime.day().month(.abbreviated)))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Color.plTextTertiary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.plBgSecondary)
        .listRowSeparatorTint(Color.plBorder)
    }
}

// MARK: - SpotPin

struct SpotPin: View {
    let spot: Spot
    let isSelected: Bool

    var category: SpotCategory { SpotCategory.from(spot.category) }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: category.colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: isSelected ? 40 : 32, height: isSelected ? 40 : 32)
                    .shadow(color: category.colors[0].opacity(isSelected ? 0.7 : 0.45), radius: isSelected ? 12 : 5)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                    )
                Image(systemName: category.icon)
                    .font(.system(size: isSelected ? 17 : 14, weight: .semibold))
                    .foregroundStyle(Color.white)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)

            Triangle()
                .fill(category.colors[1])
                .frame(width: 10, height: 6)
                .shadow(color: category.colors[1].opacity(0.4), radius: 2, y: 1)

            if isSelected {
                Text(spot.title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.plTextPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

// MARK: - Triangle

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - AddSpotSheet

struct AddSpotSheet: View {
    @Binding var isPresented: Bool
    let onSave: (String, String, String?) -> Void

    @State private var title = ""
    @State private var notes = ""
    @State private var selectedCategory: SpotCategory = .park
    @FocusState private var titleFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.plBg.ignoresSafeArea()
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Name")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.plTextTertiary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                        TextField("e.g. Morning trail", text: $title)
                            .font(.system(size: 16, design: .rounded))
                            .foregroundStyle(Color.plTextPrimary)
                            .focused($titleFocused)
                            .padding(14)
                            .background(Color.plBgSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: PLRadius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: PLRadius.md)
                                    .strokeBorder(Color.plBorder, lineWidth: 0.5)
                            )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Category")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.plTextTertiary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                            ForEach(SpotCategory.allCases) { cat in
                                let isSelected = selectedCategory == cat
                                Button(action: {
                                    selectedCategory = cat
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }) {
                                    VStack(spacing: 6) {
                                        Image(systemName: cat.icon)
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(isSelected ? Color.white : cat.colors[0])
                                        Text(cat.title)
                                            .font(.system(size: 10, weight: .medium, design: .rounded))
                                            .foregroundStyle(isSelected ? Color.white.opacity(0.9) : Color.plTextTertiary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        isSelected
                                        ? LinearGradient(colors: cat.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                                        : LinearGradient(colors: [Color.plBgSecondary, Color.plBgSecondary], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: PLRadius.md))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: PLRadius.md)
                                            .strokeBorder(isSelected ? Color.clear : Color.plBorder, lineWidth: 0.5)
                                    )
                                    .shadow(color: isSelected ? cat.colors[0].opacity(0.35) : .clear, radius: 6)
                                    .scaleEffect(isSelected ? 1.04 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.65), value: selectedCategory)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Notes (optional)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.plTextTertiary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                        TextField("Any details...", text: $notes)
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(Color.plTextPrimary)
                            .padding(14)
                            .background(Color.plBgSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: PLRadius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: PLRadius.md)
                                    .strokeBorder(Color.plBorder, lineWidth: 0.5)
                            )
                    }

                    PLPrimaryButton(title: "Save Spot", icon: "mappin.circle.fill") {
                        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        onSave(title.trimmingCharacters(in: .whitespaces), selectedCategory.rawValue, notes.isEmpty ? nil : notes)
                        isPresented = false
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(24)
            }
            .navigationTitle("Add Spot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isPresented = false }
                        .foregroundStyle(Color.plTextTertiary)
                }
            }
        }
        .onAppear { titleFocused = true }
    }
}
