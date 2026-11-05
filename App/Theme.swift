import SwiftUI
// Import only TimeRules: DUOCore also exports a global Content enum,
// which shadows ViewModifier.Content in DuoPanel's body signature.
import enum DUOCore.TimeRules

enum DuoTheme {
    static let light: [String: String] = ["Background":"F5F6F8", "Surface":"E5EAF1", "Ice":"C4D0E0", "Accent":"9AAEC8", "Text":"202632", "Secondary":"60728C", "SecondaryAccent":"697F9E"]
    static let dark: [String: String] = ["Background":"0B0D12", "Surface":"222936", "Ice":"5A6D89", "Accent":"B6C9E5", "Text":"F1F5FC", "Secondary":"B6C9E5", "SecondaryAccent":"B6C9E5"]
    static func scheme(mode: String, date: Date, start: Int, end: Int) -> ColorScheme? {
        switch mode {
        case "light": return .light
        case "dark": return .dark
        case "schedule": let c = Calendar.current.dateComponents([.hour, .minute], from: date); return TimeRules.isDark(minute: (c.hour ?? 0) * 60 + (c.minute ?? 0), start: start, end: end) ? .dark : .light
        default: return nil
        }
    }
}
struct DuoPanel: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency { content.padding().background(Color("Surface"), in: RoundedRectangle(cornerRadius: 24)) }
        else { content.padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24)) }
    }
}
extension View { func duoPanel() -> some View { modifier(DuoPanel()) } }
