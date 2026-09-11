import SwiftUI
import AppKit
import Combine

// MARK: - Active Hovered Widget Enum
enum DockWidgetType: String, CaseIterable, Identifiable {
    case focus
    case clock
    case battery
    case habits
    case water
    case notes
    
    var id: String { rawValue }
}

// MARK: - Checklist Item Model
struct ChecklistItem: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var isDone: Bool
}

// MARK: - SideDeck Observable State
class SideDeckState: ObservableObject {
    // Focus Timer
    @Published var taskName: String = "Draw the new landing page"
    @Published var focusRemaining: Int = 25 * 60
    @Published var focusTotal: Int = 25 * 60
    @Published var isFocusRunning: Bool = false
    @Published var subtasks: [ChecklistItem] = [
        ChecklistItem(text: "Draw the new landing page", isDone: false),
        ChecklistItem(text: "Reply to the framer", isDone: false),
        ChecklistItem(text: "Send the invoice", isDone: true)
    ]
    
    // Clock
    @Published var is24Hour: Bool = false
    @Published var showSeconds: Bool = false
    @Published var showDateOnCard: Bool = true
    
    // Battery & Wi-Fi
    @Published var batteryLevel: Int = 76
    @Published var isCharging: Bool = false
    @Published var isWifiOn: Bool = true
    @Published var wifiNetwork: String = "Home"
    @Published var networks: [String] = ["Home", "Studio 5G", "Cafe Guest"]
    
    // Habit Matrix (36 Days)
    @Published var habitTitle: String = "Daily Flow"
    @Published var habitStreak: Int = 18
    @Published var habitMatrix: [Double] = [
        0.65, 0.75, 0.50, 1.00, 0.65, 0.10,
        0.50, 0.75, 1.00, 0.65, 0.75, 0.50,
        0.10, 0.65, 1.00, 0.75, 0.65, 1.00,
        0.50, 0.10, 0.75, 1.00, 0.65, 0.75,
        0.50, 0.65, 1.00, 0.75, 0.10, 0.65,
        0.75, 1.00, 0.65, 0.50, 0.75, 1.00
    ]
    
    // Water Hydration
    @Published var waterMl: Int = 1750
    @Published var waterGoalMl: Int = 2500
    @Published var nextDrinkSeconds: Int = 98 // 01:38
    
    // Notes
    @Published var noteLines: [ChecklistItem] = [
        ChecklistItem(text: "Ship the update", isDone: false),
        ChecklistItem(text: "Call the framer back", isDone: false),
        ChecklistItem(text: "Rent, Friday", isDone: false)
    ]
    
    private var timerCancellable: AnyCancellable?
    
    init() {
        startClockTimer()
    }
    
    func startClockTimer() {
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.isFocusRunning && self.focusRemaining > 0 {
                    self.focusRemaining -= 1
                }
                if self.nextDrinkSeconds > 0 {
                    self.nextDrinkSeconds -= 1
                }
            }
    }
    
    func toggleFocus() {
        isFocusRunning.toggle()
    }
    
    func resetFocus(to minutes: Int = 25) {
        isFocusRunning = false
        focusTotal = minutes * 60
        focusRemaining = focusTotal
    }
    
    func addWater(amount: Int) {
        waterMl = min(waterGoalMl, waterMl + amount)
        nextDrinkSeconds = 45 * 60
    }
    
    func resetWater() {
        waterMl = 500
        nextDrinkSeconds = 30 * 60
    }
}

// MARK: - Main Root SideDeckView
struct SideDeckView: View {
    @StateObject private var state = SideDeckState()
    @State private var hoveredWidget: DockWidgetType? = nil
    @State private var wavePhase: Double = 0
    var isDockOnRight: Bool = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if isDockOnRight {
                // Flyout on Left when docked to Right edge
                flyoutContainer
                dockContainer
            } else {
                // Dock on Left, Flyout on Right
                dockContainer
                flyoutContainer
            }
        }
        .padding(8)
        .frame(width: hoveredWidget != nil ? 370 : 76, alignment: isDockOnRight ? .trailing : .leading)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: hoveredWidget)
        .onAppear {
            withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) {
                wavePhase = .pi * 2
            }
        }
    }
    
    // MARK: - Dock Column Container
    private var dockContainer: some View {
        VStack(spacing: 8) {
            // 1. Focus Card
            FocusCard(state: state, isHovered: hoveredWidget == .focus)
                .onHover { h in handleHover(.focus, isHovered: h) }
            
            // 2. Clock Card
            ClockCard(state: state, isHovered: hoveredWidget == .clock)
                .onHover { h in handleHover(.clock, isHovered: h) }
            
            // 3. Battery & Wi-Fi Status Card
            StatusCard(state: state, isHovered: hoveredWidget == .battery)
                .onHover { h in handleHover(.battery, isHovered: h) }
            
            // 4. Habit Grid Card
            HabitCard(state: state, isHovered: hoveredWidget == .habits)
                .onHover { h in handleHover(.habits, isHovered: h) }
            
            // 5. Water Cup Card
            WaterCard(state: state, wavePhase: wavePhase, isHovered: hoveredWidget == .water)
                .onHover { h in handleHover(.water, isHovered: h) }
            
            // 6. Notes Card
            NotesCard(state: state, isHovered: hoveredWidget == .notes)
                .onHover { h in handleHover(.notes, isHovered: h) }
            
            Spacer(minLength: 4)
            
            // Bottom Settings Handle
            SettingsHandle()
        }
        .padding(6)
        .frame(width: 72)
        .background(
            ZStack {
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                Color.black.opacity(0.55)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 20, x: 0, y: 8)
    }
    
    // MARK: - Flyout Detail Container
    @ViewBuilder
    private var flyoutContainer: some View {
        if let widget = hoveredWidget {
            VStack(alignment: .leading, spacing: 0) {
                switch widget {
                case .focus:
                    FocusFlyout(state: state)
                case .clock:
                    ClockFlyout(state: state)
                case .battery:
                    BatteryFlyout(state: state)
                case .habits:
                    HabitFlyout(state: state)
                case .water:
                    WaterFlyout(state: state)
                case .notes:
                    NotesFlyout(state: state)
                }
            }
            .frame(width: 270)
            .background(
                ZStack {
                    VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                    Color(red: 0.08, green: 0.09, blue: 0.12).opacity(0.92)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.55), radius: 24, x: 0, y: 10)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.94).combined(with: .opacity).combined(with: .offset(x: isDockOnRight ? 16 : -16)),
                removal: .scale(scale: 0.94).combined(with: .opacity)
            ))
            .onHover { h in
                if !h {
                    hoveredWidget = nil
                    AppDelegate.shared?.setExpanded(false)
                }
            }
        }
    }
    
    private func handleHover(_ type: DockWidgetType, isHovered: Bool) {
        if isHovered {
            hoveredWidget = type
            AppDelegate.shared?.setExpanded(true)
        }
    }
}

// MARK: - Card 1: Focus Card
struct FocusCard: View {
    @ObservedObject var state: SideDeckState
    var isHovered: Bool
    
    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                // Outer Squircle Ring
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 3)
                    .frame(width: 44, height: 44)
                
                // Progress Arc
                let fraction = state.focusTotal > 0 ? CGFloat(state.focusRemaining) / CGFloat(state.focusTotal) : 1.0
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .trim(from: 0, to: fraction)
                    .stroke(
                        LinearGradient(
                            colors: [Color(red: 0.0, green: 0.88, blue: 1.0), Color(red: 0.1, green: 0.5, blue: 1.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
                
                // Lightning Bolt Icon
                Image(systemName: "bolt.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isHovered ? .cyan : .white)
            }
            .padding(.top, 4)
            
            // Time Pill
            HStack(spacing: 2) {
                let m = state.focusRemaining / 60
                let s = state.focusRemaining % 60
                Text(String(format: "%02d", m))
                Text(":")
                    .foregroundColor(.white.opacity(0.5))
                Text(String(format: "%02d", s))
            }
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
            
            // Task Subtitle Label
            Text(state.taskName)
                .font(.system(size: 7.5, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 2)
                .padding(.bottom, 4)
        }
        .frame(width: 60)
        .background(Color.black.opacity(isHovered ? 0.65 : 0.4))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isHovered ? Color.cyan.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.03 : 1.0)
    }
}

// MARK: - Card 2: Clock Card
struct ClockCard: View {
    @ObservedObject var state: SideDeckState
    var isHovered: Bool
    @State private var currentDate = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(formatTime(currentDate))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                Text(formatAmPm(currentDate))
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Text(formatDate(currentDate))
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(width: 60, height: 42)
        .background(Color.black.opacity(isHovered ? 0.65 : 0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isHovered ? Color.cyan.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .onReceive(timer) { input in
            currentDate = input
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = state.is24Hour ? "HH:mm" : "h:mm"
        return f.string(from: date)
    }
    
    private func formatAmPm(_ date: Date) -> String {
        if state.is24Hour { return "" }
        let f = DateFormatter()
        f.dateFormat = "a"
        return f.string(from: date)
    }
    
    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "E d MMM"
        return f.string(from: date)
    }
}

// MARK: - Card 3: Battery & Wi-Fi Status Card
struct StatusCard: View {
    @ObservedObject var state: SideDeckState
    var isHovered: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            // Pill with Battery % & Wi-Fi
            HStack(spacing: 4) {
                Text("\(state.batteryLevel)%")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                Image(systemName: "wifi")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
            }
            
            // 4 Signal Dots
            HStack(spacing: 2.5) {
                Circle().fill(Color.white).frame(width: 3, height: 3)
                Circle().fill(Color.white).frame(width: 3, height: 3)
                Circle().fill(Color.white).frame(width: 3, height: 3)
                Circle().fill(Color.white.opacity(0.25)).frame(width: 3, height: 3)
            }
        }
        .frame(width: 60, height: 36)
        .background(Color.black.opacity(isHovered ? 0.65 : 0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isHovered ? Color.cyan.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.03 : 1.0)
    }
}

// MARK: - Card 4: Habit Grid Card (6x6)
struct HabitCard: View {
    @ObservedObject var state: SideDeckState
    var isHovered: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(6.5), spacing: 2.5), count: 6), spacing: 2.5) {
                ForEach(0..<36, id: \.self) { idx in
                    let val = state.habitMatrix[idx]
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(val > 0.3 ? Color.white.opacity(val) : Color.white.opacity(0.08))
                        .frame(width: 6.5, height: 6.5)
                }
            }
            .padding(4)
        }
        .frame(width: 60, height: 60)
        .background(Color.black.opacity(isHovered ? 0.65 : 0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isHovered ? Color.cyan.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.03 : 1.0)
    }
}

// MARK: - Card 5: Water Cup Card
struct WaterCard: View {
    @ObservedObject var state: SideDeckState
    var wavePhase: Double
    var isHovered: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            let m = state.nextDrinkSeconds / 60
            let s = state.nextDrinkSeconds % 60
            Text(String(format: "%02d:%02d", m, s))
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.top, 4)
            
            // Fluid Slosh Reservoir
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    WaveShape(phase: wavePhase, amplitude: isHovered ? 3.5 : 2.0)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.0, green: 0.88, blue: 1.0), Color(red: 0.1, green: 0.45, blue: 1.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: geo.size.height * 0.68)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
        .frame(width: 60, height: 60)
        .background(Color.black.opacity(isHovered ? 0.65 : 0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isHovered ? Color.cyan.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.03 : 1.0)
    }
}

// MARK: - Card 6: Notes Card
struct NotesCard: View {
    @ObservedObject var state: SideDeckState
    var isHovered: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Notes Badge
            Text("Notes")
                .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 1.5)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
                .padding(.top, 4)
                .padding(.leading, 4)
            
            // 3 lines with radio circles
            ForEach(state.noteLines.prefix(3)) { item in
                HStack(spacing: 3.5) {
                    Circle()
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                        .frame(width: 5, height: 5)
                    
                    Text(item.text)
                        .font(.system(size: 7, weight: .regular))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                }
                .padding(.horizontal, 4)
            }
            
            Spacer(minLength: 2)
        }
        .frame(width: 60, height: 62)
        .background(Color.black.opacity(isHovered ? 0.65 : 0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isHovered ? Color.cyan.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.03 : 1.0)
    }
}

// MARK: - Bottom Settings Handle
struct SettingsHandle: View {
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            AppDelegate.shared?.togglePanel()
        }) {
            Image(systemName: "gearshape")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(isHovered ? 1.0 : 0.5))
                .frame(width: 44, height: 14)
                .background(Color.white.opacity(isHovered ? 0.15 : 0.05))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - FLYOUT 1: Focus Flyout
struct FocusFlyout: View {
    @ObservedObject var state: SideDeckState
    @State private var newTaskTitle: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Tasks")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(state.subtasks.filter { !$0.isDone }.count) to go")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.cyan)
            }
            
            // Current Task Input
            VStack(alignment: .leading, spacing: 4) {
                Text("Active Task")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                TextField("Task title...", text: $state.taskName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .padding(7)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .foregroundColor(.white)
            }
            
            // Timer Controls
            HStack(spacing: 8) {
                Button(action: { state.toggleFocus() }) {
                    HStack(spacing: 5) {
                        Image(systemName: state.isFocusRunning ? "pause.fill" : "play.fill")
                        Text(state.isFocusRunning ? "Pause" : "Start")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 14)
                    .background(Color.cyan)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Button(action: { state.resetFocus(to: 25) }) {
                    Text("Reset 25m")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            
            Divider().background(Color.white.opacity(0.12))
            
            // Task List
            VStack(spacing: 6) {
                ForEach(state.subtasks) { item in
                    HStack(spacing: 8) {
                        Button(action: {
                            if let idx = state.subtasks.firstIndex(where: { $0.id == item.id }) {
                                state.subtasks[idx].isDone.toggle()
                            }
                        }) {
                            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 13))
                                .foregroundColor(item.isDone ? .cyan : .white.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                        
                        Text(item.text)
                            .font(.system(size: 11, weight: .regular))
                            .strikethrough(item.isDone)
                            .foregroundColor(item.isDone ? .white.opacity(0.4) : .white.opacity(0.9))
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
    }
}

// MARK: - FLYOUT 2: Clock Flyout
struct ClockFlyout: View {
    @ObservedObject var state: SideDeckState
    @State private var now = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Digital Clock")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text(TimeZone.current.abbreviation() ?? "GMT")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            // Large Clock
            VStack(alignment: .leading, spacing: 2) {
                Text(formatFullTime(now))
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                Text(formatFullDate(now))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            Divider().background(Color.white.opacity(0.12))
            
            // Hours Format Selector
            HStack {
                Text("Format")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                HStack(spacing: 4) {
                    Button("12-hr") { state.is24Hour = false }
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(!state.is24Hour ? Color.cyan : Color.white.opacity(0.08))
                        .foregroundColor(!state.is24Hour ? .black : .white)
                        .clipShape(Capsule())
                    
                    Button("24-hr") { state.is24Hour = true }
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(state.is24Hour ? Color.cyan : Color.white.opacity(0.08))
                        .foregroundColor(state.is24Hour ? .black : .white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .onReceive(timer) { input in
            now = input
        }
    }
    
    private func formatFullTime(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = state.is24Hour ? "HH:mm:ss" : "h:mm:ss a"
        return f.string(from: d)
    }
    
    private func formatFullDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMMM yyyy"
        return f.string(from: d)
    }
}

// MARK: - FLYOUT 3: Battery & Wi-Fi Flyout
struct BatteryFlyout: View {
    @ObservedObject var state: SideDeckState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Battery Section
            HStack {
                Text("Battery")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("On battery")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(state.batteryLevel)%")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("5h 40m left")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
                
                // Big Battery Glyph
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 44, height: 22)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.green)
                        .frame(width: 40 * CGFloat(state.batteryLevel) / 100.0, height: 16)
                        .padding(.leading, 2)
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            Divider().background(Color.white.opacity(0.12))
            
            // Wi-Fi Section
            HStack {
                Text("Wi-Fi")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Toggle("", isOn: $state.isWifiOn)
                    .toggleStyle(SwitchToggleStyle(tint: .cyan))
                    .labelsHidden()
            }
            
            if state.isWifiOn {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(state.networks, id: \.self) { net in
                        HStack(spacing: 6) {
                            Image(systemName: "wifi")
                                .font(.system(size: 10))
                                .foregroundColor(.cyan)
                            Text(net)
                                .font(.system(size: 11, weight: net == state.wifiNetwork ? .bold : .regular))
                                .foregroundColor(.white)
                            Spacer()
                            if net == state.wifiNetwork {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.cyan)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
        }
        .padding(16)
    }
}

// MARK: - FLYOUT 4: Habit Matrix Flyout
struct HabitFlyout: View {
    @ObservedObject var state: SideDeckState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Habit Matrix")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(state.habitStreak)d streak")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
            }
            
            Text("Every day you complete deep work fills a block. Tap any square to toggle.")
                .font(.system(size: 10.5, weight: .regular))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(2)
            
            // 6x6 Interactive Matrix
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(32), spacing: 5), count: 6), spacing: 5) {
                ForEach(0..<36, id: \.self) { idx in
                    let val = state.habitMatrix[idx]
                    Button(action: {
                        state.habitMatrix[idx] = (val > 0.3) ? 0.08 : 1.0
                    }) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(val > 0.3 ? Color.cyan.opacity(val) : Color.white.opacity(0.08))
                            .frame(width: 32, height: 32)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(Color.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            HStack {
                Button(action: {
                    state.habitStreak += 1
                    state.habitMatrix[35] = 1.0
                }) {
                    Text("Check in Today")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 14)
                        .background(Color.cyan)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Spacer()
                Text("82% Completion")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(16)
    }
}

// MARK: - FLYOUT 5: Water Hydration Flyout
struct WaterFlyout: View {
    @ObservedObject var state: SideDeckState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Hydration Rhythm")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                let m = state.nextDrinkSeconds / 60
                Text("Next in \(m)m")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.cyan)
            }
            
            // Progress Section
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(state.waterMl) / \(state.waterGoalMl) ml")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                    let pct = Int((Double(state.waterMl) / Double(state.waterGoalMl)) * 100)
                    Text("\(pct)%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.1)).frame(height: 8)
                        let ratio = min(1.0, CGFloat(state.waterMl) / CGFloat(state.waterGoalMl))
                        Capsule()
                            .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * ratio, height: 8)
                    }
                }
                .frame(height: 8)
            }
            .padding(10)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Quick Buttons
            HStack(spacing: 6) {
                Button("+150ml") { state.addWater(amount: 150) }
                    .font(.system(size: 10.5, weight: .semibold))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.white.opacity(0.1))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                
                Button("+250ml") { state.addWater(amount: 250) }
                    .font(.system(size: 10.5, weight: .semibold))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.cyan)
                    .foregroundColor(.black)
                    .clipShape(Capsule())
                
                Button("+500ml") { state.addWater(amount: 500) }
                    .font(.system(size: 10.5, weight: .semibold))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.white.opacity(0.1))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                
                Spacer()
                
                Button("Reset") { state.resetWater() }
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }
}

// MARK: - FLYOUT 6: Notes Flyout
struct NotesFlyout: View {
    @ObservedObject var state: SideDeckState
    @State private var newNoteLine: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Micro Scratchpad")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("Auto-saved")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            // Checklist Items
            VStack(spacing: 8) {
                ForEach(state.noteLines) { item in
                    HStack(spacing: 8) {
                        Button(action: {
                            if let idx = state.noteLines.firstIndex(where: { $0.id == item.id }) {
                                state.noteLines[idx].isDone.toggle()
                            }
                        }) {
                            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 14))
                                .foregroundColor(item.isDone ? .cyan : .white.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                        
                        Text(item.text)
                            .font(.system(size: 12, weight: .regular))
                            .strikethrough(item.isDone)
                            .foregroundColor(item.isDone ? .white.opacity(0.4) : .white)
                        
                        Spacer()
                    }
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Add Line
            HStack {
                TextField("Add task or note...", text: $newNoteLine)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .padding(6)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .foregroundColor(.white)
                
                Button(action: {
                    if !newNoteLine.isEmpty {
                        state.noteLines.append(ChecklistItem(text: newNoteLine, isDone: false))
                        newNoteLine = ""
                    }
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.black)
                        .padding(7)
                        .background(Color.cyan)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
    }
}

// MARK: - Wave Shape for Fluid Slosh
struct WaveShape: Shape {
    var phase: Double
    var amplitude: CGFloat = 2.5
    
    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midHeight = height * 0.4
        
        path.move(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: 0, y: midHeight))
        
        for x in stride(from: 0, through: width, by: 2) {
            let relativeX = x / 14
            let sine = sin(relativeX + phase)
            let y = midHeight + CGFloat(sine) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: width, y: height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Visual Effect Blur NSViewRepresentable
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}
