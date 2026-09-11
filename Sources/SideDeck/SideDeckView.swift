import SwiftUI
import AppKit
import IOKit.ps

// MARK: - App State & Settings
class SideDeckState: ObservableObject {
    @Published var focusRemaining: Int = 25 * 60
    @Published var isFocusRunning: Bool = false
    @Published var focusTotal: Int = 25 * 60
    
    @Published var batteryLevel: Int = 85
    @Published var isCharging: Bool = false
    
    @Published var waterLevel: Double = 0.75 // 0.0 to 1.0
    @Published var waterGoalGlasses: Int = 8
    @Published var waterCurrentGlasses: Int = 5
    
    @Published var streakDots: [Bool] = (0..<36).map { _ in Bool.random() }
    
    @Published var noteText: String = UserDefaults.standard.string(forKey: "SideDeck_Note") ?? "Ship the update\nReview pull requests\nRefactor shaders" {
        didSet {
            UserDefaults.standard.set(noteText, forKey: "SideDeck_Note")
        }
    }
    
    @Published var isDockOnRight: Bool = false
    
    private var timer: Timer?
    
    init() {
        updateBattery()
        startTimer()
    }
    
    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.isFocusRunning && self.focusRemaining > 0 {
                self.focusRemaining -= 1
            }
            self.updateBattery()
        }
    }
    
    func toggleFocus() {
        isFocusRunning.toggle()
    }
    
    func resetFocus() {
        isFocusRunning = false
        focusRemaining = focusTotal
    }
    
    func drinkWater() {
        if waterCurrentGlasses < waterGoalGlasses {
            waterCurrentGlasses += 1
            waterLevel = Double(waterCurrentGlasses) / Double(waterGoalGlasses)
        } else {
            waterCurrentGlasses = 1
            waterLevel = 1.0 / Double(waterGoalGlasses)
        }
    }
    
    func updateBattery() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return
        }
        for source in sources {
            if let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] {
                if let cur = desc[kIOPSCurrentCapacityKey as String] as? Int,
                   let max = desc[kIOPSMaxCapacityKey as String] as? Int {
                    DispatchQueue.main.async {
                        self.batteryLevel = max > 0 ? Int((Double(cur) / Double(max)) * 100) : cur
                        self.isCharging = (desc[kIOPSIsChargingKey as String] as? Bool) ?? false
                    }
                }
            }
        }
    }
}

// MARK: - Main SideDeck View
struct SideDeckView: View {
    @StateObject private var state = SideDeckState()
    @State private var wavePhase: Double = 0
    
    var body: some View {
        VStack(spacing: 12) {
            // 1. Focus Timer
            FocusWidget(state: state)
            
            // 2. Minimal Clock
            ClockWidget()
            
            // 3. Battery & Wi-Fi Pill
            BatteryWidget(state: state)
            
            // 4. 36-Dot Habit Heatmap
            StreakMatrixWidget(state: state)
            
            // 5. Water Hydration Slosh Cup
            WaterCupWidget(state: state, wavePhase: $wavePhase)
            
            // 6. Micro Notes Scratchpad
            NotesWidget(state: state)
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .frame(width: 72)
        .background(
            ZStack {
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                Color.black.opacity(0.4)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 8)
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                wavePhase = .pi * 2
            }
        }
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

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Focus Widget
struct FocusWidget: View {
    @ObservedObject var state: SideDeckState
    
    var progress: Double {
        Double(state.focusRemaining) / Double(state.focusTotal)
    }
    
    var formattedTime: String {
        let mins = state.focusRemaining / 60
        let secs = state.focusRemaining % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    var body: some View {
        Button(action: { state.toggleFocus() }) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 3)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(
                            LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: progress)
                    
                    Image(systemName: state.isFocusRunning ? "bolt.fill" : "bolt")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(state.isFocusRunning ? .cyan : .white)
                }
                .frame(width: 44, height: 44)
                
                Text(formattedTime)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(6)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Clock Widget
struct ClockWidget: View {
    @State private var date = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f.string(from: date)
    }
    
    var amPmString: String {
        let f = DateFormatter()
        f.dateFormat = "a"
        return f.string(from: date)
    }
    
    var dayString: String {
        let f = DateFormatter()
        f.dateFormat = "EEE d"
        return f.string(from: date)
    }
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Text(timeString)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(amPmString)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Text(dayString)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onReceive(timer) { input in
            date = input
        }
    }
}

// MARK: - Battery & Wi-Fi Widget
struct BatteryWidget: View {
    @ObservedObject var state: SideDeckState
    
    var body: some View {
        HStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(state.isCharging ? Color.green.opacity(0.8) : Color.white.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 26, height: 14)
                
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(state.isCharging ? Color.green : (state.batteryLevel < 20 ? Color.red : Color.white.opacity(0.85)))
                        .frame(width: max(2, (geo.size.width - 4) * CGFloat(state.batteryLevel) / 100))
                        .padding(2)
                }
                .frame(width: 26, height: 14)
            }
            
            Image(systemName: "wifi")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - 36-Dot Streak Matrix
struct StreakMatrixWidget: View {
    @ObservedObject var state: SideDeckState
    let columns = Array(repeating: GridItem(.fixed(7), spacing: 4), count: 6)
    
    var body: some View {
        VStack(spacing: 4) {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<36, id: \.self) { i in
                    Circle()
                        .fill(state.streakDots[i] ? Color.white.opacity(0.9) : Color.white.opacity(0.12))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(6)
        }
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Sloshing Water Cup
struct WaterCupWidget: View {
    @ObservedObject var state: SideDeckState
    @Binding var wavePhase: Double
    
    var body: some View {
        Button(action: { state.drinkWater() }) {
            VStack(spacing: 3) {
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 44, height: 46)
                    
                    // Animated Wave
                    WaveShape(phase: wavePhase, amplitude: 3)
                        .fill(
                            LinearGradient(colors: [Color.blue.opacity(0.85), Color.cyan.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                        )
                        .frame(width: 44, height: max(6, 46 * CGFloat(state.waterLevel)))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    
                    Image(systemName: "drop.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.bottom, 6)
                }
                
                Text("\(state.waterCurrentGlasses)/\(state.waterGoalGlasses) gl")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
            }
            .padding(6)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct WaveShape: Shape {
    var phase: Double
    var amplitude: Double
    
    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = Double(rect.width)
        let height = Double(rect.height)
        
        path.move(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: 0, y: amplitude * sin(phase)))
        
        for x in stride(from: 0, through: width, by: 2) {
            let relativeX = x / width
            let sine = sin(relativeX * 2 * .pi + phase)
            let y = amplitude * sine
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: width, y: height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Micro Notes Widget
struct NotesWidget: View {
    @ObservedObject var state: SideDeckState
    @State private var isEditing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("Notes")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Image(systemName: "pencil")
                    .font(.system(size: 7))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Text(state.noteText)
                .font(.system(size: 8, weight: .regular))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
        .padding(6)
        .frame(width: 58)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
