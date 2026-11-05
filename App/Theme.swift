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
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        if reduceTransparency {
            content
                .padding(16)
                .background(Color("Surface"), in: shape)
                .overlay(shape.stroke(Color("Ice").opacity(0.24), lineWidth: 1))
        } else {
            content
                .padding(16)
                .background(.regularMaterial, in: shape)
                .overlay(shape.stroke(Color("Ice").opacity(0.24), lineWidth: 1))
                .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        }
    }
}
extension View { func duoPanel() -> some View { modifier(DuoPanel()) } }
