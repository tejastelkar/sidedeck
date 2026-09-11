import SwiftUI
import AppKit
import Combine
import CoreWLAN
import IOKit.ps

// MARK: - Color Extension for Hex Initializers
extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

enum SideDeckTheme {
    static let rail = Color(hex: 0x0D0F12)
    static let surface = Color(hex: 0x171A1F)
    static let accent = Color(hex: 0x4C8DFF)
    static let secondaryText = Color(hex: 0x9299A6)
    static let border = Color(hex: 0x2A2F38)

    enum Radius {
        static let rail: CGFloat = 22
        static let flyout: CGFloat = 22
        static let card: CGFloat = 17
        static let pill: CGFloat = 18
        static let prominent: CGFloat = 16
        static let medium: CGFloat = 14
        static let button: CGFloat = 12
        static let control: CGFloat = 10
        static let field: CGFloat = 8
        static let compact: CGFloat = 7
        static let micro: CGFloat = 6
        static let indicator: CGFloat = 4
        static let heatmapCell: CGFloat = 1.5
        static let batteryFill: CGFloat = 2
        static let hydrationCard: CGFloat = 19
    }
}

// MARK: - Visual Effect Blur View for macOS Glassmorphism
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Dock Widget Enum
enum DockWidgetType: String, CaseIterable, Identifiable, Codable, Hashable {
    case focus
    case clock
    case battery
    case habits
    case water
    case notes

    var id: String { rawValue }
}

struct SideDeckLayout {
    static let dockCardWidth: CGFloat = 80.08
    static let dockPadding: CGFloat = 4.6
    static let dockSpacing: CGFloat = 4.2
    static let dockTopInset: CGFloat = 10
    static let flyoutGap: CGFloat = 6
    static let flyoutLeadingPadding: CGFloat = 20
    static let flyoutTrailingPadding: CGFloat = 30
    static let flyoutVerticalPadding: CGFloat = 20
    static let freeEdgeClearance: CGFloat = 20
    static let preferredHeight: CGFloat = 660
    static let screenVerticalMargin: CGFloat = 10
    static let collapsedTabWidth: CGFloat = 22
    static let collapsedTabHeight: CGFloat = 72

    static var dockWidth: CGFloat { dockCardWidth + dockPadding * 2 }
    static var flyoutHorizontalPadding: CGFloat { flyoutLeadingPadding + flyoutTrailingPadding }
    static var preferredPanelWidth: CGFloat {
        freeEdgeClearance + 440 + flyoutHorizontalPadding + flyoutGap + dockWidth
    }

    let panelSize: CGSize

    init(availableSize: CGSize) {
        panelSize = CGSize(
            width: min(Self.preferredPanelWidth, max(0, availableSize.width)),
            height: min(Self.preferredHeight, max(0, availableSize.height - Self.screenVerticalMargin * 2))
        )
    }

    static let preferred = SideDeckLayout(
        availableSize: CGSize(width: preferredPanelWidth, height: preferredHeight + screenVerticalMargin * 2)
    )

    func preferredFlyoutContentWidth(for type: DockWidgetType) -> CGFloat {
        type == .habits || type == .water ? 440 : 340
    }

    func flyoutOuterWidth(for type: DockWidgetType) -> CGFloat {
        let available = max(0, panelSize.width - Self.dockWidth - Self.flyoutGap - Self.freeEdgeClearance)
        return min(preferredFlyoutContentWidth(for: type) + Self.flyoutHorizontalPadding, available)
    }

    func flyoutContentWidth(for type: DockWidgetType) -> CGFloat {
        max(0, flyoutOuterWidth(for: type) - Self.flyoutHorizontalPadding)
    }

    func preferredFlyoutHeight(for type: DockWidgetType) -> CGFloat {
        switch type {
        case .focus: return 340
        case .clock: return 220
        case .battery: return 350
        case .habits: return 310
        case .water: return 290
        case .notes: return 280
        }
    }

    func dockCardCenterY(for type: DockWidgetType) -> CGFloat {
        let top = Self.dockTopInset + Self.dockPadding
        switch type {
        case .focus: return top + 135.1 / 2
        case .clock: return top + 135.1 + Self.dockSpacing + 55.4 / 2
        case .battery: return top + 135.1 + Self.dockSpacing + 55.4 + Self.dockSpacing + 55.4 / 2
        case .habits: return top + 135.1 + Self.dockSpacing + 55.4 + Self.dockSpacing + 55.4 + Self.dockSpacing + 80.1 / 2
        case .water: return top + 135.1 + Self.dockSpacing + 55.4 + Self.dockSpacing + 55.4 + Self.dockSpacing + 80.1 + Self.dockSpacing + 80.1 / 2
        case .notes: return top + 135.1 + Self.dockSpacing + 55.4 + Self.dockSpacing + 55.4 + Self.dockSpacing + 80.1 + Self.dockSpacing + 80.1 + Self.dockSpacing + 74.3 / 2
        }
    }

    func flyoutHeight(for type: DockWidgetType) -> CGFloat {
        min(preferredFlyoutHeight(for: type), max(0, panelSize.height - Self.screenVerticalMargin * 2))
    }

    func flyoutTop(for type: DockWidgetType) -> CGFloat {
        let height = flyoutHeight(for: type)
        let centered = dockCardCenterY(for: type) - height / 2
        return max(
            Self.screenVerticalMargin,
            min(panelSize.height - Self.screenVerticalMargin - height, centered)
        )
    }

    func flyoutFrame(for type: DockWidgetType, dockOnRight: Bool) -> CGRect {
        flyoutFrame(for: type, in: CGRect(origin: .zero, size: panelSize), dockOnRight: dockOnRight)
    }

    func flyoutFrame(for type: DockWidgetType, in bounds: CGRect, dockOnRight: Bool) -> CGRect {
        let width = flyoutOuterWidth(for: type)
        let x = dockOnRight
            ? bounds.maxX - Self.dockWidth - Self.flyoutGap - width
            : bounds.minX + Self.dockWidth + Self.flyoutGap
        return CGRect(
            x: x,
            y: bounds.minY + flyoutTop(for: type),
            width: width,
            height: flyoutHeight(for: type)
        )
    }
}

// MARK: - Checklist Item Model
struct ChecklistItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var text: String
    var isDone: Bool
    var tag: String? = nil
    var createdAt: Date = Date()

    var timeAgoString: String {
        timeAgoString(relativeTo: Date())
    }

    func timeAgoString(relativeTo now: Date) -> String {
        let elapsed = max(0, Int(now.timeIntervalSince(createdAt)))
        if elapsed < 60 { return "just now" }
        if elapsed < 3_600 {
            let minutes = elapsed / 60
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        }
        if elapsed < 86_400 {
            let hours = elapsed / 3_600
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        }
        let days = elapsed / 86_400
        return days == 1 ? "yesterday" : "\(days) days ago"
    }
}

// MARK: - Host Delegate Protocol
@MainActor
public protocol SideDeckHostDelegate: AnyObject {
    func setExpanded(_ expanded: Bool)
    func openMenu()
    func refreshDockMenu()
}

// MARK: - Hover State & Debounce Coordinator
@MainActor
class SideDeckHoverState: ObservableObject {
    weak var delegate: SideDeckHostDelegate?
    @Published var activeWidget: DockWidgetType? = nil
    @Published var isHoveringFlyout: Bool = false
    @Published var isHandleHovered: Bool = false
    @Published private(set) var isDockCollapsed: Bool = false
    @Published private(set) var isPinned: Bool

    private var collapseWorkItem: DispatchWorkItem?
    private var hoveredCard: DockWidgetType?
    private var clickedWidget: DockWidgetType?
    private let defaults: UserDefaults
    private let collapseDelay: Double

    init(defaults: UserDefaults = .standard, collapseDelay: Double = 0.16) {
        self.defaults = defaults
        self.collapseDelay = collapseDelay
        self.isPinned = defaults.object(forKey: "sidedeck_dock_pinned") as? Bool ?? true
    }

    func setPinned(_ pinned: Bool) {
        isPinned = pinned
        defaults.set(pinned, forKey: "sidedeck_dock_pinned")
        if pinned {
            expandDock()
        }
        delegate?.refreshDockMenu()
    }

    func togglePinned() {
        setPinned(!isPinned)
    }

    func expandDock() {
        collapseWorkItem?.cancel()
        if isDockCollapsed {
            isDockCollapsed = false
            delegate?.setExpanded(true)
        }
    }

    func collapseDock() {
        setPinned(false)
        collapseWorkItem?.cancel()
        hoveredCard = nil
        isHoveringFlyout = false
        activeWidget = nil
        clickedWidget = nil
        isDockCollapsed = true
        delegate?.setExpanded(false)
    }

    func hoverCard(_ type: DockWidgetType) {
        expandDock()
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
        hoveredCard = type
        if clickedWidget == nil, activeWidget != type {
            activeWidget = type
            delegate?.setExpanded(true)
        }
    }

    func toggleCard(_ type: DockWidgetType) {
        expandDock()
        collapseWorkItem?.cancel()
        withAnimation(.easeOut(duration: 0.14)) {
            if clickedWidget == type {
                clickedWidget = nil
                activeWidget = nil
            } else {
                clickedWidget = type
                activeWidget = type
            }
        }
    }

    func exitCard(_ type: DockWidgetType) {
        guard hoveredCard == type else { return }
        hoveredCard = nil
        scheduleCollapseIfOutside()
    }

    func hoverFlyout() {
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
        isHoveringFlyout = true
    }

    func exitFlyout() {
        isHoveringFlyout = false
        scheduleCollapseIfOutside()
    }

    func scheduleCollapseIfOutside(delay: Double? = nil) {
        collapseWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if self.hoveredCard == nil && !self.isHoveringFlyout && self.clickedWidget == nil {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    self.activeWidget = nil
                }
                if !self.isPinned {
                    self.isDockCollapsed = true
                }
                self.delegate?.setExpanded(!self.isDockCollapsed)
            }
        }
        collapseWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + (delay ?? collapseDelay), execute: item)
    }
}

// MARK: - Observable Application State with Real Hardware Integration & Persistence
class SideDeckState: ObservableObject {
    // Focus Timer
    @Published var taskName: String = "Draw the new landing page"
    @Published var focusRemaining: Int = 4 * 60 + 38
    @Published var focusTotal: Int = 25 * 60
    @Published var isFocusRunning: Bool = false
    @Published var subtasks: [ChecklistItem] = []
    @Published var newTaskInput: String = ""

    // Clock
    @Published var is24Hour: Bool = false
    @Published var showSeconds: Bool = false
    @Published var showDateOnCard: Bool = true
    @Published var hourModeIndex: Int = 0 // 0: System, 1: 12-hour, 2: 24-hour
    @Published var currentDate: Date = Date()

    // Real System Battery & Wi-Fi
    @Published var batteryLevel: Int = 100
    @Published var isCharging: Bool = false
    @Published var timeRemainingMinutes: Int? = nil
    @Published var isWifiOn: Bool = true
    @Published var wifiNetwork: String = "Wi-Fi"
    @Published var wifiRSSI: Int = -60
    @Published var networks: [(name: String, strength: Int, locked: Bool, current: Bool)] = []

    // Habit Grid (36 days)
    @Published var habitStreak: Int = 6
    @Published var habitTodayCount: Int = 4
    @Published var habitMatrix: [Int] = []
    @Published var annualHabitMatrix: [Int] = []

    // Water Hydration
    @Published var waterMl: Int = 1750
    @Published var waterGoalMl: Int = 2500
    @Published var nextDrinkSeconds: Int = 98
    @Published var hydrationInterval: String = "45 min"
    @Published var drinkHistory: [Int] = [3, 5, 2, 6, 4, 7, 3, 8, 5, 2, 6, 4, 7, 4]

    // Notes
    @Published var noteLines: [ChecklistItem] = []
    @Published var newNoteInput: String = ""

    private var timerCancellable: AnyCancellable?
    private let defaults: UserDefaults
    private var lastHabitCheckIn: Date?

    init(defaults: UserDefaults = .standard, startServices: Bool = true) {
        self.defaults = defaults
        loadPersistedData()
        applyHourMode()

        if startServices {
            updateSystemBattery()
            updateSystemWifi()

            timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] now in
                    guard let self = self else { return }
                    self.advanceOneSecond(now: now)
                    if Int(now.timeIntervalSince1970) % 5 == 0 {
                        self.updateSystemBattery()
                        self.updateSystemWifi()
                    }
                }
        }
    }

    func advanceOneSecond(now: Date) {
        currentDate = now
        if isFocusRunning {
            focusRemaining = max(0, focusRemaining - 1)
            if focusRemaining == 0 {
                isFocusRunning = false
            }
        }
        nextDrinkSeconds = max(0, nextDrinkSeconds - 1)
    }

    // MARK: - Real Battery Monitoring
    func updateSystemBattery() {
        if let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] {
            for source in sources {
                if let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] {
                    if let cap = desc[kIOPSCurrentCapacityKey] as? Int {
                        self.batteryLevel = cap
                    }
                    if let charging = desc[kIOPSIsChargingKey] as? Bool {
                        self.isCharging = charging
                    }
                    if let time = desc[kIOPSTimeToEmptyKey] as? Int, time > 0 {
                        self.timeRemainingMinutes = time
                    } else if let time = desc[kIOPSTimeToFullChargeKey] as? Int, time > 0 {
                        self.timeRemainingMinutes = time
                    } else {
                        self.timeRemainingMinutes = nil
                    }
                }
            }
        }
    }

    // MARK: - Real Wi-Fi Monitoring
    func updateSystemWifi() {
        if let iface = CWWiFiClient.shared().interface() {
            self.isWifiOn = iface.powerOn()
            if let ssid = iface.ssid(), !ssid.isEmpty {
                self.wifiNetwork = ssid
            } else {
                self.wifiNetwork = iface.powerOn() ? "Connected" : "Wi-Fi Off"
            }
            self.wifiRSSI = iface.rssiValue()

            self.networks = self.isWifiOn && self.wifiNetwork != "Connected"
                ? [(name: self.wifiNetwork, strength: self.wifiRSSI, locked: false, current: true)]
                : []
        }
    }

    func toggleWifiPower() {
        if let iface = CWWiFiClient.shared().interface() {
            do {
                try iface.setPower(!self.isWifiOn)
                self.isWifiOn.toggle()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.updateSystemWifi()
                }
            } catch {
                print("Failed to toggle Wi-Fi: \(error)")
            }
        }
    }

    // MARK: - Persistence
    func loadPersistedData() {
        // Tasks
        if let data = defaults.data(forKey: "sidedeck_tasks"),
           let loaded = try? JSONDecoder().decode([ChecklistItem].self, from: data) {
            self.subtasks = loaded
            if let active = loaded.first(where: { !$0.isDone }) {
                self.taskName = active.text
            }
        } else {
            self.subtasks = [
                ChecklistItem(text: "Draw the new landing page", isDone: false, tag: "25:00"),
                ChecklistItem(text: "Reply to the framer", isDone: false, tag: "10:00"),
                ChecklistItem(text: "Send the invoice", isDone: true)
            ]
            self.taskName = "Draw the new landing page"
        }

        // Notes
        if let data = defaults.data(forKey: "sidedeck_notes"),
           let loaded = try? JSONDecoder().decode([ChecklistItem].self, from: data) {
            self.noteLines = loaded
        } else {
            self.noteLines = [
                ChecklistItem(text: "Ship the update", isDone: false, createdAt: Date().addingTimeInterval(-120)),
                ChecklistItem(text: "Call the framer back", isDone: false, createdAt: Date().addingTimeInterval(-3600)),
                ChecklistItem(text: "Rent, Friday", isDone: false, createdAt: Date().addingTimeInterval(-86400))
            ]
        }

        // Habits
        if let savedHabits = defaults.array(forKey: "sidedeck_habits") as? [Int], savedHabits.count == 36 {
            self.habitMatrix = savedHabits
        } else {
            self.habitMatrix = [
                2,3,1,4,2,0,
                1,3,4,2,3,1,
                0,2,4,3,2,4,
                1,0,3,4,2,3,
                1,2,4,3,0,2,
                3,4,2,1,3,4
            ]
        }

        // Annual Habits (140 dots)
        if let savedAnnual = defaults.array(forKey: "sidedeck_annual_habits") as? [Int], savedAnnual.count == 140 {
            self.annualHabitMatrix = savedAnnual
        } else {
            self.annualHabitMatrix = (0..<140).map { ($0 * 7 + 3) % 5 }
        }
        self.habitStreak = defaults.object(forKey: "sidedeck_habit_streak") == nil
            ? 0
            : defaults.integer(forKey: "sidedeck_habit_streak")
        self.habitTodayCount = defaults.object(forKey: "sidedeck_habit_today_count") == nil
            ? 0
            : defaults.integer(forKey: "sidedeck_habit_today_count")
        self.lastHabitCheckIn = defaults.object(forKey: "sidedeck_habit_last_checkin") as? Date

        // Water
        if defaults.object(forKey: "sidedeck_water_ml") != nil {
            self.waterMl = defaults.integer(forKey: "sidedeck_water_ml")
        }

        // Clock settings
        self.showSeconds = defaults.bool(forKey: "sidedeck_show_seconds")
        if defaults.object(forKey: "sidedeck_show_date") != nil {
            self.showDateOnCard = defaults.bool(forKey: "sidedeck_show_date")
        }
        self.hourModeIndex = min(2, max(0, defaults.integer(forKey: "sidedeck_hour_mode")))
    }

    func applyHourMode() {
        if hourModeIndex == 0 {
            let format = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current) ?? "h a"
            is24Hour = !format.contains("a")
        } else {
            is24Hour = hourModeIndex == 2
        }
    }

    func saveTasks() {
        if let data = try? JSONEncoder().encode(subtasks) {
            defaults.set(data, forKey: "sidedeck_tasks")
        }
    }

    func saveNotes() {
        if let data = try? JSONEncoder().encode(noteLines) {
            defaults.set(data, forKey: "sidedeck_notes")
        }
    }

    func saveHabits() {
        defaults.set(habitMatrix, forKey: "sidedeck_habits")
        defaults.set(annualHabitMatrix, forKey: "sidedeck_annual_habits")
    }

    func saveWater() {
        defaults.set(waterMl, forKey: "sidedeck_water_ml")
    }

    func saveClockSettings() {
        defaults.set(showSeconds, forKey: "sidedeck_show_seconds")
        defaults.set(showDateOnCard, forKey: "sidedeck_show_date")
        defaults.set(hourModeIndex, forKey: "sidedeck_hour_mode")
    }

    // MARK: - Interactive Actions
    func toggleFocusTimer() {
        isFocusRunning.toggle()
    }

    func resetFocusTimer(to minutes: Int = 25) {
        isFocusRunning = false
        focusTotal = minutes * 60
        focusRemaining = focusTotal
    }

    func selectActiveTask(_ item: ChecklistItem) {
        self.taskName = item.text
    }

    func toggleTask(_ item: ChecklistItem) {
        if let idx = subtasks.firstIndex(where: { $0.id == item.id }) {
            subtasks[idx].isDone.toggle()
            if subtasks[idx].isDone && taskName == subtasks[idx].text {
                taskName = subtasks.first(where: { !$0.isDone })?.text ?? "No active task"
            }
            saveTasks()
        }
    }

    func deleteTask(_ item: ChecklistItem) {
        subtasks.removeAll(where: { $0.id == item.id })
        if taskName == item.text {
            taskName = subtasks.first(where: { !$0.isDone })?.text ?? "No active task"
        }
        saveTasks()
    }

    func clearDoneTasks() {
        subtasks.removeAll(where: { $0.isDone })
        saveTasks()
    }

    func addTask() {
        let trimmed = newTaskInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let item = ChecklistItem(text: trimmed, isDone: false, tag: "25:00")
        subtasks.insert(item, at: 0)
        taskName = trimmed
        newTaskInput = ""
        saveTasks()
    }

    func toggleNote(_ item: ChecklistItem) {
        if let idx = noteLines.firstIndex(where: { $0.id == item.id }) {
            noteLines[idx].isDone.toggle()
            saveNotes()
        }
    }

    func deleteNote(_ item: ChecklistItem) {
        noteLines.removeAll(where: { $0.id == item.id })
        saveNotes()
    }

    func addNote() {
        let trimmed = newNoteInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let item = ChecklistItem(text: trimmed, isDone: false, createdAt: Date())
        noteLines.insert(item, at: 0)
        newNoteInput = ""
        saveNotes()
    }

    func toggleHabitCell(at index: Int) {
        guard habitMatrix.indices.contains(index) else { return }
        habitMatrix[index] = (habitMatrix[index] + 1) % 5
        saveHabits()
    }

    func toggleAnnualHabitCell(at index: Int) {
        guard annualHabitMatrix.indices.contains(index) else { return }
        annualHabitMatrix[index] = (annualHabitMatrix[index] + 1) % 5
        saveHabits()
    }

    func checkInToday(on date: Date = Date()) {
        if let lastHabitCheckIn, Calendar.current.isDate(lastHabitCheckIn, inSameDayAs: date) {
            return
        }

        if let lastHabitCheckIn,
           let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date),
           Calendar.current.isDate(lastHabitCheckIn, inSameDayAs: yesterday) {
            habitStreak += 1
        } else {
            habitStreak = 1
        }
        habitTodayCount += 1
        lastHabitCheckIn = date
        if !habitMatrix.isEmpty {
            habitMatrix[habitMatrix.count - 1] = min(4, habitMatrix[habitMatrix.count - 1] + 1)
        }
        defaults.set(habitStreak, forKey: "sidedeck_habit_streak")
        defaults.set(habitTodayCount, forKey: "sidedeck_habit_today_count")
        defaults.set(date, forKey: "sidedeck_habit_last_checkin")
        saveHabits()
    }

    func addDrink(amount: Int = 250) {
        guard amount > 0 else { return }
        waterMl = min(waterGoalMl, waterMl + amount)
        nextDrinkSeconds = 45 * 60
        if let last = drinkHistory.last {
            drinkHistory[drinkHistory.count - 1] = last + 1
        }
        saveWater()
    }

    func resetWater() {
        waterMl = 0
        saveWater()
    }
}

// MARK: - Exact Callout Shape with 12px Curved Beak
struct FlyoutCalloutShape: Shape {
    var beakY: CGFloat
    var isPointingLeft: Bool = true

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let beakW: CGFloat = 12
        let r = min(SideDeckTheme.Radius.flyout, min(w, h) / 2)
        let safeBeakY = min(max(beakY, r + 25), h - r - 25)

        if isPointingLeft {
            let leftX = beakW
            path.move(to: CGPoint(x: leftX + r, y: 0))
            path.addLine(to: CGPoint(x: w - r, y: 0))
            path.addArc(center: CGPoint(x: w - r, y: r), radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            path.addLine(to: CGPoint(x: w, y: h - r))
            path.addArc(center: CGPoint(x: w - r, y: h - r), radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            path.addLine(to: CGPoint(x: leftX + r, y: h))
            path.addArc(center: CGPoint(x: leftX + r, y: h - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)

            // Left edge up to beak
            path.addLine(to: CGPoint(x: leftX, y: safeBeakY + 21))

            // Beak tip at x = 0.5
            path.addCurve(
                to: CGPoint(x: 0.5, y: safeBeakY),
                control1: CGPoint(x: leftX - 3.2, y: safeBeakY + 11.5),
                control2: CGPoint(x: 1.5, y: safeBeakY + 2.5)
            )
            path.addCurve(
                to: CGPoint(x: leftX, y: safeBeakY - 21),
                control1: CGPoint(x: 1.5, y: safeBeakY - 2.5),
                control2: CGPoint(x: leftX - 3.2, y: safeBeakY - 11.5)
            )

            path.addLine(to: CGPoint(x: leftX, y: r))
            path.addArc(center: CGPoint(x: leftX + r, y: r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            path.closeSubpath()
        } else {
            let rightX = w - beakW
            path.move(to: CGPoint(x: r, y: 0))
            path.addLine(to: CGPoint(x: rightX - r, y: 0))
            path.addArc(center: CGPoint(x: rightX - r, y: r), radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)

            // Right edge down to beak
            path.addLine(to: CGPoint(x: rightX, y: safeBeakY - 21))
            path.addCurve(
                to: CGPoint(x: w - 0.5, y: safeBeakY),
                control1: CGPoint(x: rightX + 3.2, y: safeBeakY - 11.5),
                control2: CGPoint(x: w - 1.5, y: safeBeakY - 2.5)
            )
            path.addCurve(
                to: CGPoint(x: rightX, y: safeBeakY + 21),
                control1: CGPoint(x: w - 1.5, y: safeBeakY + 2.5),
                control2: CGPoint(x: rightX + 3.2, y: safeBeakY + 11.5)
            )

            path.addLine(to: CGPoint(x: rightX, y: h - r))
            path.addArc(center: CGPoint(x: rightX - r, y: h - r), radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            path.addLine(to: CGPoint(x: r, y: h))
            path.addArc(center: CGPoint(x: r, y: h - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            path.addLine(to: CGPoint(x: 0, y: r))
            path.addArc(center: CGPoint(x: r, y: r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            path.closeSubpath()
        }
        return path
    }
}

// MARK: - Main Root SideDeckView
struct SideDeckView: View {
    var isDockOnRight: Bool = true
    @ObservedObject var hoverState: SideDeckHoverState
    @ObservedObject var state: SideDeckState
    let layout: SideDeckLayout
    @State private var wavePhase: Double = 0

    init(
        isDockOnRight: Bool = true,
        hoverState: SideDeckHoverState,
        state: SideDeckState = SideDeckState(),
        layout: SideDeckLayout = .preferred
    ) {
        self.isDockOnRight = isDockOnRight
        self.hoverState = hoverState
        self.state = state
        self.layout = layout
    }

    private var cardW: CGFloat { SideDeckLayout.dockCardWidth }
    private var dockPadding: CGFloat { SideDeckLayout.dockPadding }
    private var cardSpacing: CGFloat { SideDeckLayout.dockSpacing }

    var body: some View {
        ZStack(alignment: isDockOnRight ? .topTrailing : .topLeading) {
            if hoverState.isDockCollapsed {
                collapsedEdgeTab
            } else {
                dockContainer
                    .offset(x: 0, y: SideDeckLayout.dockTopInset)
                    .transition(.move(edge: isDockOnRight ? .trailing : .leading).combined(with: .opacity))
            }

            // 2. Active Flyout Popover with pointed callout arrow
            if !hoverState.isDockCollapsed, let active = hoverState.activeWidget {
                let coords = flyoutCoordinates(for: active)
                let flyoutX = isDockOnRight
                    ? -(SideDeckLayout.dockWidth + SideDeckLayout.flyoutGap)
                    : (SideDeckLayout.dockWidth + SideDeckLayout.flyoutGap)

                flyoutWrapper(for: active, beakY: coords.beakY)
                    .offset(x: flyoutX, y: coords.y)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity).combined(with: .offset(x: isDockOnRight ? 12 : -12)),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
                    .onHover { h in
                        if h {
                            hoverState.hoverFlyout()
                        } else {
                            hoverState.exitFlyout()
                        }
                    }
            }
        }
        .frame(
            width: layout.panelSize.width,
            height: layout.panelSize.height,
            alignment: isDockOnRight ? .topTrailing : .topLeading
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.88), value: hoverState.isDockCollapsed)
        .onAppear {
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                wavePhase = .pi * 2
            }
        }
    }

    private var collapsedEdgeTab: some View {
        Button(action: { hoverState.expandDock() }) {
            RoundedRectangle(cornerRadius: SideDeckTheme.Radius.control, style: .continuous)
                .fill(Color(hex: 0x171A1F))
                .frame(width: SideDeckLayout.collapsedTabWidth, height: SideDeckLayout.collapsedTabHeight)
                .overlay(
                    Image(systemName: isDockOnRight ? "chevron.left" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(hex: 0x9299A6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: SideDeckTheme.Radius.control, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .frame(maxHeight: .infinity)
        .onHover { hovering in
            if hovering { hoverState.expandDock() }
        }
        .accessibilityLabel("Expand SideDeck")
    }

    // MARK: - Dock Column Container
    private var dockContainer: some View {
        VStack(spacing: cardSpacing) {
            // 1. Focus Card
            FocusCard(state: state)
                .cardDimming(isActive: hoverState.activeWidget == nil || hoverState.activeWidget == .focus)
                .contentShape(Rectangle())
                .onTapGesture { hoverState.toggleCard(.focus) }
                .onHover { h in
                    if h { hoverState.hoverCard(.focus) } else { hoverState.exitCard(.focus) }
                }

            // 2. Clock Card
            ClockCard(state: state)
                .cardDimming(isActive: hoverState.activeWidget == nil || hoverState.activeWidget == .clock)
                .contentShape(Rectangle())
                .onTapGesture { hoverState.toggleCard(.clock) }
                .onHover { h in
                    if h { hoverState.hoverCard(.clock) } else { hoverState.exitCard(.clock) }
                }

            // 3. Status Card (Real Battery + Wi-Fi)
            StatusCard(state: state)
                .cardDimming(isActive: hoverState.activeWidget == nil || hoverState.activeWidget == .battery)
                .contentShape(Rectangle())
                .onTapGesture { hoverState.toggleCard(.battery) }
                .onHover { h in
                    if h { hoverState.hoverCard(.battery) } else { hoverState.exitCard(.battery) }
                }

            // 4. Habits Card
            HabitsCard(state: state)
                .cardDimming(isActive: hoverState.activeWidget == nil || hoverState.activeWidget == .habits)
                .contentShape(Rectangle())
                .onTapGesture { hoverState.toggleCard(.habits) }
                .onHover { h in
                    if h { hoverState.hoverCard(.habits) } else { hoverState.exitCard(.habits) }
                }

            // 5. Hydration Card (Dynamic Water Level)
            HydrationCard(state: state, wavePhase: wavePhase)
                .cardDimming(isActive: hoverState.activeWidget == nil || hoverState.activeWidget == .water)
                .contentShape(Rectangle())
                .onTapGesture { hoverState.toggleCard(.water) }
                .onHover { h in
                    if h { hoverState.hoverCard(.water) } else { hoverState.exitCard(.water) }
                }

            // 6. Notes Card
            NotesCard(state: state)
                .cardDimming(isActive: hoverState.activeWidget == nil || hoverState.activeWidget == .notes)
                .contentShape(Rectangle())
                .onTapGesture { hoverState.toggleCard(.notes) }
                .onHover { h in
                    if h { hoverState.hoverCard(.notes) } else { hoverState.exitCard(.notes) }
                }

            // 7. Bottom Expanding Handle
            SettingsHandle(hoverState: hoverState)
        }
        .padding(dockPadding)
        .frame(width: SideDeckLayout.dockWidth)
        .background(
            ZStack {
                VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
                SideDeckTheme.rail.opacity(0.94)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: SideDeckTheme.Radius.rail, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SideDeckTheme.Radius.rail, style: .continuous)
                .stroke(SideDeckTheme.border.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 14, x: 0, y: 6)
        .onHover { hovering in
            if hovering {
                hoverState.expandDock()
            } else {
                hoverState.scheduleCollapseIfOutside()
            }
        }
    }

    // MARK: - Flyout Wrapper with Shape & Shadow
    @ViewBuilder
    private func flyoutWrapper(for type: DockWidgetType, beakY: CGFloat) -> some View {
        let flyoutWidth = layout.flyoutContentWidth(for: type)

        Group {
            switch type {
            case .focus:
                FocusFlyout(state: state)
            case .clock:
                ClockFlyout(state: state)
            case .battery:
                StatusFlyout(state: state)
            case .habits:
                HabitsFlyout(state: state)
            case .water:
                HydrationFlyout(state: state)
            case .notes:
                NotesFlyout(state: state)
            }
        }
        .frame(width: flyoutWidth)
        .fixedSize(horizontal: false, vertical: true)
        .padding(
            .leading,
            isDockOnRight ? SideDeckLayout.flyoutLeadingPadding : SideDeckLayout.flyoutTrailingPadding
        )
        .padding(
            .trailing,
            isDockOnRight ? SideDeckLayout.flyoutTrailingPadding : SideDeckLayout.flyoutLeadingPadding
        )
        .padding(.vertical, SideDeckLayout.flyoutVerticalPadding)
        .background(
            ZStack {
                VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
                SideDeckTheme.rail.opacity(0.96)
            }
        )
        .clipShape(FlyoutCalloutShape(beakY: beakY, isPointingLeft: !isDockOnRight))
        .overlay(
            FlyoutCalloutShape(beakY: beakY, isPointingLeft: !isDockOnRight)
                .stroke(SideDeckTheme.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.48), radius: 18, x: 0, y: 8)
    }

    // MARK: - Coordinate Math for Aligning Beak with Card Center
    private func flyoutCoordinates(for type: DockWidgetType) -> (y: CGFloat, beakY: CGFloat, width: CGFloat) {
        let flyoutW = layout.flyoutContentWidth(for: type)
        let topY = layout.flyoutTop(for: type)
        let beakY = layout.dockCardCenterY(for: type) - topY

        return (y: topY, beakY: beakY, width: flyoutW)
    }
}

// MARK: - Sibling Card Dimming View Modifier
extension View {
    func cardDimming(isActive: Bool) -> some View {
        self
            .opacity(isActive ? 1.0 : 0.58)
            .animation(.easeOut(duration: 0.14), value: isActive)
    }
}

// MARK: - Base Pitch Black Card Container Modifier
struct SydedockCardModifier: ViewModifier {
    var height: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(width: 80.08, height: height)
            .background(SideDeckTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: SideDeckTheme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SideDeckTheme.Radius.card, style: .continuous)
                    .stroke(SideDeckTheme.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 3, x: 0, y: 1)
    }
}

// MARK: - CARD 1: FOCUS CARD
struct FocusCard: View {
    @ObservedObject var state: SideDeckState

    var body: some View {
        VStack(spacing: 8) {
            // Squircle Bolt Ring - Clicking toggles Play / Pause
            Button(action: { state.toggleFocusTimer() }) {
                ZStack {
                    SquircleTrackShape()
                        .stroke(Color(hex: 0x262626), lineWidth: 9.6)
                        .frame(width: 56.56, height: 56.56)

                    SquircleTrackShape()
                        .trim(from: 0, to: Double(state.focusRemaining) / Double(state.focusTotal))
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: 0x0068fe), Color(hex: 0x1c79ff)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            style: StrokeStyle(lineWidth: 4.38, lineCap: .round)
                        )
                        .frame(width: 56.56, height: 56.56)
                        .rotationEffect(.degrees(-90))

                    SydedockBoltGlyph()
                        .frame(width: 22, height: 26)
                        .opacity(state.isFocusRunning ? 1.0 : 0.65)
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            // Time Pill
            HStack(spacing: 2.5) {
                let mins = String(format: "%02d", state.focusRemaining / 60)
                let secs = String(format: "%02d", state.focusRemaining % 60)
                Text(mins)
                    .font(.system(size: 14.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text(":")
                    .font(.system(size: 14.5, weight: .bold, design: .monospaced))
                    .foregroundColor(state.isFocusRunning ? Color(hex: 0x626262) : Color.white.opacity(0.3))
                Text(secs)
                    .font(.system(size: 14.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            .frame(width: 66.2, height: 24.3)
            .background(Color.black)
            .cornerRadius(SideDeckTheme.Radius.button)
            .overlay(
                RoundedRectangle(cornerRadius: SideDeckTheme.Radius.button, style: .continuous)
                    .stroke(Color(hex: 0x424242), lineWidth: 0.8)
            )

            // Task strip with fade mask
            Text(state.taskName)
                .font(.system(size: 8.4, weight: .medium, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.68))
                .lineLimit(1)
                .padding(.horizontal, 4)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .white, location: 0.82),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .padding(.vertical, 8)
        .modifier(SydedockCardModifier(height: 135.1))
    }
}

// MARK: - Squircle Track Shape
struct SquircleTrackShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r: CGFloat = 11.0
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: w / 2, y: 0))
        path.addLine(to: CGPoint(x: w - r, y: 0))
        path.addArc(center: CGPoint(x: w - r, y: r), radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: w, y: h - r))
        path.addArc(center: CGPoint(x: w - r, y: h - r), radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: r, y: h))
        path.addArc(center: CGPoint(x: r, y: h - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: 0, y: r))
        path.addArc(center: CGPoint(x: r, y: r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}

// MARK: - Exact Sydedock Lightning Bolt SVG Glyph
struct SydedockBoltGlyph: View {
    var body: some View {
        GeometryReader { geo in
            Path { p in
                let sx = geo.size.width / 120.0
                let sy = geo.size.height / 120.0

                p.move(to: CGPoint(x: 64.0 * sx, y: 14.0 * sy))
                p.addLine(to: CGPoint(x: 32.0 * sx, y: 64.0 * sy))
                p.addLine(to: CGPoint(x: 58.0 * sx, y: 64.0 * sy))
                p.addLine(to: CGPoint(x: 48.0 * sx, y: 106.0 * sy))
                p.addLine(to: CGPoint(x: 88.0 * sx, y: 52.0 * sy))
                p.addLine(to: CGPoint(x: 62.0 * sx, y: 52.0 * sy))
                p.closeSubpath()
            }
            .fill(Color.white)
        }
    }
}

// MARK: - CARD 2: CLOCK CARD
struct ClockCard: View {
    @ObservedObject var state: SideDeckState

    var timeString: String {
        let formatter = DateFormatter()
        if state.is24Hour {
            formatter.dateFormat = state.showSeconds ? "HH:mm:ss" : "HH:mm"
        } else {
            formatter.dateFormat = state.showSeconds ? "h:mm:ss" : "h:mm"
        }
        return formatter.string(from: state.currentDate)
    }

    var meridiemString: String {
        if state.is24Hour { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "a"
        return formatter.string(from: state.currentDate)
    }

    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        return formatter.string(from: state.currentDate)
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(timeString)
                    .font(.system(size: state.showSeconds ? 14.5 : 18.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                if !state.is24Hour {
                    Text(meridiemString)
                        .font(.system(size: 7.2, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.5))
                }
            }
            if state.showDateOnCard {
                Text(dateString)
                    .font(.system(size: 9.2, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.5))
            }
        }
        .modifier(SydedockCardModifier(height: 55.44))
    }
}

// MARK: - CARD 3: STATUS CARD (Real Battery + Wi-Fi)
struct StatusCard: View {
    @ObservedObject var state: SideDeckState

    var signalDotsCount: Int {
        if !state.isWifiOn { return 0 }
        if state.wifiRSSI >= -55 { return 4 }
        if state.wifiRSSI >= -70 { return 3 }
        if state.wifiRSSI >= -85 { return 2 }
        return 1
    }

    var body: some View {
        ZStack {
            // Racetrack Stadium Outline Path with gap at bottom
            RacetrackOutlineShape()
                .stroke(Color.white.opacity(0.22), lineWidth: 2.8)
                .frame(width: 72, height: 28)

            // Filled progress stroke (real Mac battery)
            RacetrackOutlineShape()
                .trim(from: 0, to: Double(state.batteryLevel) / 100.0)
                .stroke(
                    state.isCharging ? Color.green : Color(hex: 0x1c79ff),
                    style: StrokeStyle(lineWidth: 2.8, lineCap: .round)
                )
                .frame(width: 72, height: 28)

            // Inside Racetrack: Real % on left, Wi-Fi icon on right
            HStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(state.batteryLevel)")
                        .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("%")
                        .font(.system(size: 7.5, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.55))
                }
                Spacer()
                // Wi-Fi icon
                WifiIconGlyph()
                    .frame(width: 12, height: 10)
                    .opacity(state.isWifiOn ? 1.0 : 0.3)
            }
            .padding(.horizontal, 10)
            .frame(width: 72)

            // Bottom 4 signal status dots based on real RSSI
            VStack {
                Spacer()
                HStack(spacing: 3) {
                    ForEach(0..<4) { idx in
                        Circle()
                            .fill(idx < signalDotsCount ? Color.white : Color.white.opacity(0.25))
                            .frame(width: 2.8, height: 2.8)
                    }
                }
                .padding(.bottom, 5)
            }
        }
        .modifier(SydedockCardModifier(height: 55.44))
    }
}

// MARK: - Racetrack Stadium Outline Shape
struct RacetrackOutlineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = rect.height / 2
        let w = rect.width
        let h = rect.height
        let gap: CGFloat = 16.0

        path.move(to: CGPoint(x: (w - gap) / 2, y: h))
        path.addLine(to: CGPoint(x: r, y: h))
        path.addArc(center: CGPoint(x: r, y: r), radius: r, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
        path.addLine(to: CGPoint(x: w - r, y: 0))
        path.addArc(center: CGPoint(x: w - r, y: r), radius: r, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: (w + gap) / 2, y: h))
        return path
    }
}

// MARK: - Wi-Fi SVG Glyph
struct WifiIconGlyph: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Path { p in
                p.move(to: CGPoint(x: w * 0.1, y: h * 0.3))
                p.addQuadCurve(to: CGPoint(x: w * 0.9, y: h * 0.3), control: CGPoint(x: w * 0.5, y: -h * 0.2))

                p.move(to: CGPoint(x: w * 0.25, y: h * 0.6))
                p.addQuadCurve(to: CGPoint(x: w * 0.75, y: h * 0.6), control: CGPoint(x: w * 0.5, y: h * 0.25))
            }
            .stroke(Color.white, style: StrokeStyle(lineWidth: 1.3, lineCap: .round))

            Path { p in
                p.addArc(center: CGPoint(x: w * 0.5, y: h * 0.85), radius: 1.2, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: true)
            }
            .fill(Color.white)
        }
    }
}

// MARK: - CARD 4: HABITS CARD
struct HabitsCard: View {
    @ObservedObject var state: SideDeckState

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(6.3), spacing: 4.7), count: 6),
            spacing: 4.7
        ) {
            ForEach(0..<state.habitMatrix.count, id: \.self) { idx in
                let val = state.habitMatrix[idx]
                Button(action: { state.toggleHabitCell(at: idx) }) {
                    if val == 0 {
                        Circle()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 6.3, height: 6.3)
                            .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.6))
                    } else if val == 1 {
                        Circle().fill(Color.white.opacity(0.35)).frame(width: 6.3, height: 6.3)
                    } else if val == 2 {
                        Circle().fill(Color(hex: 0xa1a1a1)).frame(width: 6.3, height: 6.3)
                    } else if val == 3 {
                        Circle().fill(Color.white.opacity(0.75)).frame(width: 6.3, height: 6.3)
                    } else {
                        Circle().fill(Color.white).frame(width: 6.3, height: 6.3)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 80.08, height: 80.08)
        .modifier(SydedockCardModifier(height: 80.08))
    }
}

// MARK: - CARD 5: HYDRATION CARD (Dynamic Water Height)
struct HydrationCard: View {
    @ObservedObject var state: SideDeckState
    var wavePhase: Double

    var countdownString: String {
        let mins = String(format: "%02d", state.nextDrinkSeconds / 60)
        let secs = String(format: "%02d", state.nextDrinkSeconds % 60)
        return "\(mins):\(secs)"
    }

    // Dynamic height based on real logged water intake!
    var dynamicWaveHeight: CGFloat {
        let ratio = CGFloat(state.waterMl) / CGFloat(state.waterGoalMl)
        return max(18, min(65, 80.08 * ratio))
    }

    var body: some View {
        ZStack {
            // Dynamic Fluid Sine-Wave Water Reservoir
            VStack {
                Spacer()
                ZStack {
                    WaveShape(phase: wavePhase + .pi, amplitude: 2.2, wavelength: 40)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0x00e1ff).opacity(0.6), Color(hex: 0x1b79ff).opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: dynamicWaveHeight + 4)

                    WaveShape(phase: wavePhase, amplitude: 2.5, wavelength: 45)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0x00e1ff), Color(hex: 0x1b79ff)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: dynamicWaveHeight)
                }
                .animation(.spring(response: 0.55, dampingFraction: 0.8), value: dynamicWaveHeight)
            }
            .clipShape(RoundedRectangle(cornerRadius: SideDeckTheme.Radius.hydrationCard, style: .continuous))

            // Countdown Text on top
            VStack {
                Text(countdownString)
                    .font(.system(size: 14.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.top, 10)
                Spacer()
            }
        }
        .modifier(SydedockCardModifier(height: 80.08))
    }
}

// MARK: - Wave Shape for Fluid Animation
struct WaveShape: Shape {
    var phase: Double
    var amplitude: CGFloat = 3.0
    var wavelength: CGFloat = 50.0

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let midY = amplitude + 2

        path.move(to: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: 0, y: midY))

        for x in stride(from: 0, through: w, by: 2) {
            let relativeX = x / wavelength
            let sine = sin(relativeX * 2 * .pi + CGFloat(phase))
            let y = midY + sine * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: w, y: h))
        path.closeSubpath()
        return path
    }
}

// MARK: - CARD 6: NOTES CARD
struct NotesCard: View {
    @ObservedObject var state: SideDeckState

    var body: some View {
        VStack(spacing: 3) {
            HStack {
                Text("Notes")
                    .font(.system(size: 6.8, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(width: 65.8, height: 13.8)
            .background(
                LinearGradient(
                    colors: [Color.black, Color(hex: 0x2f2f2f)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(SideDeckTheme.Radius.compact)
            .padding(.top, 4)

            // 3 Real Notes checklist lines
            VStack(spacing: 2) {
                ForEach(Array(state.noteLines.prefix(3))) { item in
                    HStack(spacing: 4) {
                        Button(action: { state.toggleNote(item) }) {
                            ZStack {
                                Circle()
                                    .fill(item.isDone ? SideDeckTheme.accent : Color.clear)
                                    .overlay(Circle().stroke(item.isDone ? SideDeckTheme.accent : SideDeckTheme.secondaryText, lineWidth: 1))
                                if item.isDone {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 5.5, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(width: 10, height: 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .frame(width: 18, height: 14)
                        .accessibilityLabel(item.text)
                        .accessibilityValue(item.isDone ? "Completed" : "Not completed")

                        Text(item.text)
                            .font(.system(size: 6.8, weight: .regular))
                            .strikethrough(item.isDone)
                            .foregroundColor(item.isDone ? Color.white.opacity(0.4) : Color.white.opacity(0.8))
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 6)
                    .frame(height: 14)

                    if item.id != state.noteLines.prefix(3).last?.id {
                        Divider()
                            .background(Color.white.opacity(0.09))
                            .padding(.horizontal, 6)
                    }
                }
            }
            Spacer()
        }
        .modifier(SydedockCardModifier(height: 74.34))
    }
}

// MARK: - CARD 7: BOTTOM EXPANDING HANDLE
struct SettingsHandle: View {
    @ObservedObject var hoverState: SideDeckHoverState

    var body: some View {
        HStack(spacing: 3) {
            handleButton(
                symbol: hoverState.isPinned ? "pin.fill" : "pin",
                label: hoverState.isPinned ? "Use auto-collapse" : "Keep dock open"
            ) {
                hoverState.togglePinned()
            }

            handleButton(symbol: "chevron.compact.right", label: "Collapse to edge") {
                hoverState.collapseDock()
            }

            handleButton(symbol: "ellipsis", label: "Open SideDeck menu") {
                hoverState.delegate?.openMenu()
            }
        }
        .frame(width: 80.08, height: 30)
    }

    private func handleButton(
        symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(hex: 0x9299A6))
                .frame(width: 22, height: 22)
                .background(Color.white.opacity(0.055))
                .clipShape(RoundedRectangle(cornerRadius: SideDeckTheme.Radius.compact, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}

// MARK: - FLYOUT 1: TASKS FLYOUT (Fully Interactive)
struct FocusFlyout: View {
    @ObservedObject var state: SideDeckState
    @FocusState private var isInputFocused: Bool

    var pendingCount: Int {
        state.subtasks.filter { !$0.isDone }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text("Tasks")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text("\(pendingCount) to go")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.55))
                Spacer()

                // Quick timer preset pills
                HStack(spacing: 4) {
                    Button(action: { state.resetFocusTimer(to: 25) }) {
                        Text("25m").font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Color.white.opacity(0.1)).cornerRadius(SideDeckTheme.Radius.micro)
                    }.buttonStyle(.plain)

                    Button(action: { state.resetFocusTimer(to: 15) }) {
                        Text("15m").font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Color.white.opacity(0.1)).cornerRadius(SideDeckTheme.Radius.micro)
                    }.buttonStyle(.plain)

                    Button(action: { state.resetFocusTimer(to: 5) }) {
                        Text("5m").font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Color.white.opacity(0.1)).cornerRadius(SideDeckTheme.Radius.micro)
                    }.buttonStyle(.plain)
                }
            }

            // Task List
            VStack(spacing: 5) {
                ForEach(state.subtasks) { item in
                    HStack(spacing: 10) {
                        Button(action: { state.toggleTask(item) }) {
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.4), lineWidth: 1.2)
                                    .frame(width: 16, height: 16)
                                if item.isDone {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 16, height: 16)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.black)
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        Text(item.text)
                            .font(.system(size: 13, weight: .regular))
                            .strikethrough(item.isDone)
                            .foregroundColor(item.isDone ? Color.white.opacity(0.4) : .white)
                            .lineLimit(1)
                            .onTapGesture {
                                state.selectActiveTask(item)
                            }

                        Spacer()

                        if let tag = item.tag, !item.isDone {
                            Text(tag)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.55))
                        }

                        Button(action: { state.deleteTask(item) }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10))
                                .foregroundColor(Color.white.opacity(0.35))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: SideDeckTheme.Radius.control, style: .continuous)
                            .fill(item.text == state.taskName ? Color(hex: 0x1c79ff, alpha: 0.14) : Color.white.opacity(0.07))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: SideDeckTheme.Radius.control, style: .continuous)
                            .stroke(item.text == state.taskName ? Color(hex: 0x1c79ff, alpha: 0.8) : Color.clear, lineWidth: 1)
                    )
                }
            }

            // Clear Done action
            HStack {
                Spacer()
                Button(action: { state.clearDoneTasks() }) {
                    Text("Clear \(state.subtasks.filter { $0.isDone }.count) done")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.55))
                }
                .buttonStyle(.plain)
            }

            // Real Working TextField
            HStack(spacing: 8) {
                TextField("Add a task…", text: $state.newTaskInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .focused($isInputFocused)
                    .onSubmit {
                        state.addTask()
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(SideDeckTheme.Radius.pill)

                Button(action: {
                    state.addTask()
                }) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0x0068fe), Color(hex: 0x1c79ff)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 34, height: 34)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - FLYOUT 2: CLOCK FLYOUT (Fully Interactive)
struct ClockFlyout: View {
    @ObservedObject var state: SideDeckState

    var timeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = state.is24Hour ? "HH:mm:ss" : "h:mm:ss"
        return formatter.string(from: state.currentDate)
    }

    var meridiemFormatted: String {
        if state.is24Hour { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "a"
        return formatter.string(from: state.currentDate)
    }

    var fullDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: state.currentDate)
    }

    var weekOfYear: Int {
        Calendar.current.component(.weekOfYear, from: state.currentDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Digital clock")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text(TimeZone.current.abbreviation() ?? "IST")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.55))
            }

            // Hero Box
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(timeFormatted)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    if !state.is24Hour {
                        Text(meridiemFormatted)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.6))
                    }
                }
                Text("\(fullDateFormatted) · Week \(weekOfYear)")
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.55))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: 0x1c79ff, alpha: 0.14))
            .cornerRadius(SideDeckTheme.Radius.control)
            .overlay(
                RoundedRectangle(cornerRadius: SideDeckTheme.Radius.control, style: .continuous)
                    .stroke(Color(hex: 0x1c79ff, alpha: 0.8), lineWidth: 1)
            )

            // Interactive Hours Selector
            HStack {
                Text("Hours")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white)
                Spacer()
                HStack(spacing: 3) {
                    Button(action: {
                        state.hourModeIndex = 0
                        state.applyHourMode()
                        state.saveClockSettings()
                    }) {
                        Text("System")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(state.hourModeIndex == 0 ? .white : Color.white.opacity(0.55))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(state.hourModeIndex == 0 ? Color(hex: 0x1c79ff) : Color.clear)
                            .cornerRadius(SideDeckTheme.Radius.button)
                    }.buttonStyle(.plain)

                    Button(action: {
                        state.hourModeIndex = 1
                        state.is24Hour = false
                        state.saveClockSettings()
                    }) {
                        Text("12-hour")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(state.hourModeIndex == 1 ? .white : Color.white.opacity(0.55))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(state.hourModeIndex == 1 ? Color(hex: 0x1c79ff) : Color.clear)
                            .cornerRadius(SideDeckTheme.Radius.button)
                    }.buttonStyle(.plain)

                    Button(action: {
                        state.hourModeIndex = 2
                        state.is24Hour = true
                        state.saveClockSettings()
                    }) {
                        Text("24-hour")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(state.hourModeIndex == 2 ? .white : Color.white.opacity(0.55))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(state.hourModeIndex == 2 ? Color(hex: 0x1c79ff) : Color.clear)
                            .cornerRadius(SideDeckTheme.Radius.button)
                    }.buttonStyle(.plain)
                }
                .padding(3)
                .background(Color.black.opacity(0.45))
                .cornerRadius(SideDeckTheme.Radius.medium)
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(Color.white.opacity(0.07))
            .cornerRadius(SideDeckTheme.Radius.control)

            // Interactive Card Options (Seconds & Date)
            HStack {
                Text("On the card")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white)
                Spacer()
                HStack(spacing: 4) {
                    Button(action: {
                        state.showSeconds.toggle()
                        state.saveClockSettings()
                    }) {
                        Text("Seconds")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(state.showSeconds ? .white : Color.white.opacity(0.55))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(state.showSeconds ? Color(hex: 0x1c79ff) : Color.clear)
                            .cornerRadius(SideDeckTheme.Radius.button)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        state.showDateOnCard.toggle()
                        state.saveClockSettings()
                    }) {
                        Text("Date")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(state.showDateOnCard ? .white : Color.white.opacity(0.55))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(state.showDateOnCard ? Color(hex: 0x1c79ff) : Color.clear)
                            .cornerRadius(SideDeckTheme.Radius.button)
                    }
                    .buttonStyle(.plain)
                }
                .padding(3)
                .background(Color.black.opacity(0.45))
                .cornerRadius(SideDeckTheme.Radius.medium)
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(Color.white.opacity(0.07))
            .cornerRadius(SideDeckTheme.Radius.control)
        }
    }
}

// MARK: - FLYOUT 3: STATUS / BATTERY & WI-FI FLYOUT (Real Hardware)
struct StatusFlyout: View {
    @ObservedObject var state: SideDeckState

    var timeRemainingText: String {
        if state.isCharging {
            if let mins = state.timeRemainingMinutes {
                return "\(mins / 60)h \(mins % 60)m until full"
            }
            return "Charging"
        } else {
            if let mins = state.timeRemainingMinutes {
                return "\(mins / 60)h \(mins % 60)m left"
            }
            return "On battery"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text("Battery")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text(state.isCharging ? "Charging" : "On battery")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.55))
            }

            // Battery Hero
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(state.batteryLevel)%")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text(timeRemainingText)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.6))
                }
                Spacer()
                // Battery outline icon with dynamic fill
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: SideDeckTheme.Radius.indicator)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        .frame(width: 32, height: 16)
                    RoundedRectangle(cornerRadius: SideDeckTheme.Radius.batteryFill)
                        .fill(state.isCharging ? Color.green : Color.white)
                        .frame(width: 32 * CGFloat(state.batteryLevel) / 100.0 * 0.9, height: 12)
                        .padding(.leading, 2)
                }
            }
            .padding(12)
            .background(Color(hex: 0x1c79ff, alpha: 0.14))
            .cornerRadius(SideDeckTheme.Radius.control)
            .overlay(
                RoundedRectangle(cornerRadius: SideDeckTheme.Radius.control, style: .continuous)
                    .stroke(Color(hex: 0x1c79ff, alpha: 0.8), lineWidth: 1)
            )

            // Wi-Fi Subhead & Toggle
            HStack {
                Text("Wi‑Fi")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: { state.toggleWifiPower() }) {
                    Text(state.isWifiOn ? "On" : "Off")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(state.isWifiOn ? .white : Color.white.opacity(0.5))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(state.isWifiOn ? Color(hex: 0x1c79ff) : Color.white.opacity(0.1))
                        .cornerRadius(SideDeckTheme.Radius.button)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)

            // Wi-Fi Hero
            HStack(spacing: 12) {
                WifiIconGlyph()
                    .frame(width: 24, height: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.wifiNetwork)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Signal: \(state.wifiRSSI) dBm · \(state.isWifiOn ? "Active" : "Disconnected")")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.6))
                }
                Spacer()
            }
            .padding(12)
            .background(Color.white.opacity(0.07))
            .cornerRadius(SideDeckTheme.Radius.control)

            // Networks list
            VStack(spacing: 4) {
                ForEach(state.networks, id: \.name) { net in
                    HStack(spacing: 10) {
                        WifiIconGlyph().frame(width: 14, height: 12)
                        Text(net.name)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.white)
                        Spacer()
                        if net.current {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: 0x1c79ff))
                        }
                        if net.locked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color.white.opacity(0.4))
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(net.current ? Color(hex: 0x1c79ff, alpha: 0.14) : Color.white.opacity(0.04))
                    .cornerRadius(SideDeckTheme.Radius.field)
                }
            }

            // Link to macOS Wi-Fi Settings
            HStack {
                Spacer()
                Button(action: {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension")!)
                }) {
                    Text("Wi‑Fi Settings…")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.55))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
    }
}

// MARK: - FLYOUT 4: HABITS FLYOUT (Interactive Matrix & Streak)
struct HabitsFlyout: View {
    @ObservedObject var state: SideDeckState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Habits")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text("\(state.habitStreak) day streak")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.55))
                Spacer()
                Button(action: { state.checkInToday() }) {
                    Text("Check in Today")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color(hex: 0x1c79ff))
                        .cornerRadius(SideDeckTheme.Radius.button)
                }
                .buttonStyle(.plain)
            }

            // Today count hero
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today's Check-ins")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.6))
                    Text("\(state.habitTodayCount)")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("Less").font(.system(size: 10)).foregroundColor(Color.white.opacity(0.45))
                    Circle().fill(Color.white.opacity(0.05)).frame(width: 7, height: 7)
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                    Circle().fill(Color.white.opacity(0.35)).frame(width: 7, height: 7)
                    Circle().fill(Color(hex: 0xa1a1a1)).frame(width: 7, height: 7)
                    Circle().fill(Color.white.opacity(0.75)).frame(width: 7, height: 7)
                    Circle().fill(Color.white).frame(width: 7, height: 7)
                    Text("More").font(.system(size: 10)).foregroundColor(Color.white.opacity(0.45))
                }
            }
            .padding(12)
            .background(Color(hex: 0x1c79ff, alpha: 0.14))
            .cornerRadius(SideDeckTheme.Radius.control)
            .overlay(
                RoundedRectangle(cornerRadius: SideDeckTheme.Radius.control, style: .continuous)
                    .stroke(Color(hex: 0x1c79ff, alpha: 0.8), lineWidth: 1)
            )

            // 52-week interactive activity dot matrix
            VStack(alignment: .leading, spacing: 4) {
                Text("Annual History (Click any dot to log)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.45))

                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(7), spacing: 3), count: 28),
                    spacing: 3
                ) {
                    ForEach(0..<state.annualHabitMatrix.count, id: \.self) { idx in
                        let lvl = state.annualHabitMatrix[idx]
                        Button(action: { state.toggleAnnualHabitCell(at: idx) }) {
                            if lvl == 0 {
                                RoundedRectangle(cornerRadius: SideDeckTheme.Radius.heatmapCell)
                                    .fill(Color.white.opacity(0.05))
                                    .frame(width: 7, height: 7)
                                    .overlay(RoundedRectangle(cornerRadius: SideDeckTheme.Radius.heatmapCell).stroke(Color.white.opacity(0.2), lineWidth: 0.4))
                            } else if lvl == 1 {
                                RoundedRectangle(cornerRadius: SideDeckTheme.Radius.heatmapCell).fill(Color.white.opacity(0.35)).frame(width: 7, height: 7)
                            } else if lvl == 2 {
                                RoundedRectangle(cornerRadius: SideDeckTheme.Radius.heatmapCell).fill(Color(hex: 0xa1a1a1)).frame(width: 7, height: 7)
                            } else if lvl == 3 {
                                RoundedRectangle(cornerRadius: SideDeckTheme.Radius.heatmapCell).fill(Color.white.opacity(0.75)).frame(width: 7, height: 7)
                            } else {
                                RoundedRectangle(cornerRadius: SideDeckTheme.Radius.heatmapCell).fill(Color.white).frame(width: 7, height: 7)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(8)
            .background(Color.white.opacity(0.04))
            .cornerRadius(SideDeckTheme.Radius.field)

            Text("Tasks completed today")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.white.opacity(0.55))

            VStack(spacing: 4) {
                let doneTasks = state.subtasks.filter { $0.isDone }
                if doneTasks.isEmpty {
                    Text("No tasks completed yet. Check off a task to log it!")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.35))
                        .padding(8)
                } else {
                    ForEach(doneTasks) { t in
                        HStack(spacing: 8) {
                            Circle().fill(Color.white).frame(width: 14, height: 14)
                                .overlay(Image(systemName: "checkmark").font(.system(size: 8, weight: .bold)).foregroundColor(.black))
                            Text(t.text).font(.system(size: 12)).strikethrough().foregroundColor(Color.white.opacity(0.5))
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(SideDeckTheme.Radius.micro)
                    }
                }
            }
        }
    }
}

// MARK: - FLYOUT 5: HYDRATION FLYOUT (Interactive Water Logging)
struct HydrationFlyout: View {
    @ObservedObject var state: SideDeckState

    var countdownString: String {
        let mins = String(format: "%02d", state.nextDrinkSeconds / 60)
        let secs = String(format: "%02d", state.nextDrinkSeconds % 60)
        return "\(mins):\(secs)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Main Column
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Hydration")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text("\(state.waterMl) / \(state.waterGoalMl) ml")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.55))
                    Spacer()
                }

                // Next reminder hero
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next reminder in")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.6))
                        Text(countdownString)
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Button(action: { state.addDrink(amount: 250) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 12))
                            Text("+250ml")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: 0x0068fe), Color(hex: 0x1c79ff)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(SideDeckTheme.Radius.prominent)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Color(hex: 0x1c79ff, alpha: 0.14))
                .cornerRadius(SideDeckTheme.Radius.control)
                .overlay(
                    RoundedRectangle(cornerRadius: SideDeckTheme.Radius.control, style: .continuous)
                        .stroke(Color(hex: 0x1c79ff, alpha: 0.8), lineWidth: 1)
                )

                // Quick log presets
                HStack(spacing: 6) {
                    Button(action: { state.addDrink(amount: 150) }) {
                        Text("+150ml").font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.white).padding(.horizontal, 8).padding(.vertical, 5)
                            .background(Color.white.opacity(0.08)).cornerRadius(SideDeckTheme.Radius.field)
                    }.buttonStyle(.plain)

                    Button(action: { state.addDrink(amount: 500) }) {
                        Text("+500ml").font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.white).padding(.horizontal, 8).padding(.vertical, 5)
                            .background(Color.white.opacity(0.08)).cornerRadius(SideDeckTheme.Radius.field)
                    }.buttonStyle(.plain)

                    Spacer()

                    Button(action: { state.resetWater() }) {
                        Text("Reset").font(.system(size: 11, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.4)).padding(.horizontal, 8).padding(.vertical, 5)
                    }.buttonStyle(.plain)
                }
            }
            .frame(width: 230)

            // Vertical Divider
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1)

            // Aside: Real 14-day Drinks Chart
            VStack(alignment: .leading, spacing: 8) {
                Text("Last 14 days")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                HStack {
                    Text("Today").font(.system(size: 11)).foregroundColor(Color.white.opacity(0.6))
                    Spacer()
                    Text("\(state.drinkHistory.last ?? 0) drinks").font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundColor(.white)
                }

                // Dynamic Bar Chart
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(state.drinkHistory.indices, id: \.self) { idx in
                        let val = state.drinkHistory[idx]
                        RoundedRectangle(cornerRadius: SideDeckTheme.Radius.heatmapCell)
                            .fill(idx == state.drinkHistory.count - 1 ? Color(hex: 0x00e1ff) : Color(hex: 0x1c79ff))
                            .frame(width: 6, height: CGFloat(max(4, val * 4)))
                    }
                }
                .frame(height: 36)

                Divider().background(Color.white.opacity(0.1))

                HStack {
                    Text("Streak").font(.system(size: 11)).foregroundColor(Color.white.opacity(0.6))
                    Spacer()
                    Text("7 days").font(.system(size: 11, weight: .bold)).foregroundColor(Color(hex: 0x1c79ff))
                }
                HStack {
                    Text("Average").font(.system(size: 11)).foregroundColor(Color.white.opacity(0.6))
                    Spacer()
                    Text("4.6 a day").font(.system(size: 11)).foregroundColor(.white)
                }
            }
            .frame(width: 140)
        }
    }
}

// MARK: - FLYOUT 6: NOTES FLYOUT (Interactive multi-item scratchpad)
struct NotesFlyout: View {
    @ObservedObject var state: SideDeckState
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text("Notes")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text("\(state.noteLines.count)")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.55))
                Spacer()
            }

            // Notes rows
            VStack(spacing: 5) {
                if state.noteLines.isEmpty {
                    Text("No notes yet. Type something below to save a quick thought.")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.35))
                        .padding(10)
                } else {
                    ForEach(state.noteLines) { item in
                        HStack(spacing: 10) {
                            Button(action: { state.toggleNote(item) }) {
                                ZStack {
                                    Circle()
                                        .fill(item.isDone ? SideDeckTheme.accent : Color.clear)
                                        .overlay(Circle().stroke(item.isDone ? SideDeckTheme.accent : SideDeckTheme.secondaryText, lineWidth: 1.2))
                                    if item.isDone {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(width: 16, height: 16)
                            }
                            .buttonStyle(.plain)
                            .frame(width: 24, height: 24)
                            .accessibilityLabel(item.text)
                            .accessibilityValue(item.isDone ? "Completed" : "Not completed")

                            Text(item.text)
                                .font(.system(size: 13, weight: .regular))
                                .strikethrough(item.isDone)
                                .foregroundColor(item.isDone ? Color.white.opacity(0.4) : .white)
                                .lineLimit(1)

                            Spacer()

                            Text(item.timeAgoString)
                                .font(.system(size: 10, weight: .regular, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.45))

                            Button(action: { state.deleteNote(item) }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color.white.opacity(0.35))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background(Color.white.opacity(0.07))
                        .cornerRadius(SideDeckTheme.Radius.field)
                    }
                }
            }

            // Real Working Note Input
            HStack(spacing: 8) {
                TextField("Jot something down…", text: $state.newNoteInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .focused($isInputFocused)
                    .onSubmit {
                        state.addNote()
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(SideDeckTheme.Radius.pill)

                Button(action: {
                    state.addNote()
                }) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0x0068fe), Color(hex: 0x1c79ff)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 34, height: 34)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
