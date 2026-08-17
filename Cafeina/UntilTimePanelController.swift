import AppKit

/// Small non-modal panel behind "Keep Awake ▸ Until a Time…".
///
/// The user picks a wall-clock time; on confirm the panel resolves it to the
/// next occurrence of that time (today if still ahead, otherwise tomorrow) and
/// hands the resulting `Date` to the caller.
@MainActor
final class UntilTimePanelController: NSWindowController {
    static let shared = UntilTimePanelController()

    private let datePicker = NSDatePicker()
    private var onConfirm: ((Date) -> Void)?

    private init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 160),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Keep Awake Until a Time"
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        super.init(window: panel)
        buildContent(in: panel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Activates the app and shows the panel. `onConfirm` receives the resolved
    /// end time when the user presses "Keep Awake".
    func show(onConfirm: @escaping (Date) -> Void) {
        self.onConfirm = onConfirm
        datePicker.dateValue = Self.nextFullHour(after: Date())

        NSApp.activate(ignoringOtherApps: true)
        if window?.isVisible == false {
            window?.center()
        }
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(datePicker)
    }

    // MARK: - Date math

    /// The next moment strictly after `now` whose hour and minute match `time`:
    /// today if that time is still ahead, otherwise tomorrow. Seconds are zeroed.
    static func nextOccurrence(of time: Date, after now: Date = Date(), calendar: Calendar = .current) -> Date? {
        let picked = calendar.dateComponents([.hour, .minute], from: time)
        var target = DateComponents()
        target.hour = picked.hour
        target.minute = picked.minute
        target.second = 0
        return calendar.nextDate(after: now, matching: target, matchingPolicy: .nextTime)
    }

    /// The start of the hour following `now` (e.g. 14:37 → 15:00).
    static func nextFullHour(after now: Date = Date(), calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: now)
        guard let startOfHour = calendar.date(from: components),
              let next = calendar.date(byAdding: .hour, value: 1, to: startOfHour) else {
            return now.addingTimeInterval(3600)
        }
        return next
    }

    // MARK: - Actions

    @objc private func confirm(_ sender: Any?) {
        let target = Self.nextOccurrence(of: datePicker.dateValue)
        let callback = onConfirm
        onConfirm = nil
        close()

        if let target {
            callback?(target)
        }
    }

    @objc private func cancel(_ sender: Any?) {
        onConfirm = nil
        close()
    }

    // MARK: - Layout

    private func buildContent(in panel: NSPanel) {
        let prompt = NSTextField(labelWithString: "Keep this Mac awake until:")
        prompt.font = .systemFont(ofSize: 13, weight: .semibold)

        datePicker.datePickerStyle = .textFieldAndStepper
        datePicker.datePickerElements = .hourMinute
        datePicker.datePickerMode = .single

        let hint = NSTextField(
            wrappingLabelWithString: "If that time has already passed today, Cafeina keeps your Mac awake until it comes around tomorrow."
        )
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel(_:)))
        cancelButton.keyEquivalent = "\u{1b}"

        let confirmButton = NSButton(title: "Keep Awake", target: self, action: #selector(confirm(_:)))
        confirmButton.keyEquivalent = "\r"

        // Gravity areas keep the buttons at their natural size, pushed to the trailing edge.
        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.distribution = .gravityAreas
        buttons.spacing = 8
        buttons.addView(cancelButton, in: .trailing)
        buttons.addView(confirmButton, in: .trailing)

        let stack = NSStackView(views: [prompt, datePicker, hint, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.setCustomSpacing(18, after: hint)
        stack.translatesAutoresizingMaskIntoConstraints = false

        guard let contentView = panel.contentView else {
            return
        }
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            hint.widthAnchor.constraint(equalToConstant: 280),
            buttons.trailingAnchor.constraint(equalTo: hint.trailingAnchor)
        ])

        contentView.layoutSubtreeIfNeeded()
        panel.setContentSize(contentView.fittingSize)
    }
}
