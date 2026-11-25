import SwiftUI
import UIKit
import EventKit
import DUOCore

/// Lit les calendriers de l'iPhone (iCloud, Google, Exchange…) en lecture seule, après accord.
@MainActor @Observable final class CalendarBridge {
    static let shared = CalendarBridge()
    let ek = EKEventStore()
    private(set) var granted = false
    private(set) var denied = false
    private(set) var revision = 0
    init() { refresh() }
    func refresh() {
        let st = EKEventStore.authorizationStatus(for: .event)
        granted = st == .fullAccess
        denied = st == .denied || st == .restricted
        revision += 1
    }
    func request() async {
        _ = try? await ek.requestFullAccessToEvents()
        refresh()
    }
    func events(on day: Date) -> [EKEvent] {
        guard granted else { return [] }
        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
        return ek.events(matching: ek.predicateForEvents(withStart: start, end: end, calendars: nil)).sorted { $0.startDate < $1.startDate }
    }
}

/// Le calendrier du couple : un mois en grille, puis l'agenda du jour choisi
/// (horaires de travail, tâches, repas, rendez-vous DUO et calendriers de l'iPhone).
struct DayV2: View {
    @Environment(AppStore.self) private var store
    @State private var selected = Calendar.current.startOfDay(for: Date())
    @State private var month = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
    @State private var calBridge = CalendarBridge.shared
    @State private var addEvent = false
    @State private var editRow: Record?

    struct Item: Identifiable {
        let id = UUID(); let minute: Int; let who: String; let title: String; let tint: Color; let symbol: String
        var row: Record? = nil; var allDay = false
    }
    private var cal: Calendar { var c = Calendar.current; c.firstWeekday = 2; return c }

    private func items(on day: Date) -> [Item] {
        var list: [Item] = []
        let c = cal
        for p in DuoPerson.allCases {
            if let w = DuoSchedule.work(p, on: day) {
                list.append(Item(minute: w.start, who: p.rawValue, title: w.label + " · jusqu'à " + hm(w.end), tint: P.person(p), symbol: "briefcase.fill"))
            }
        }
        for (r, t) in store.taskRows where t.completed == nil {
            guard let due = t.due, c.isDate(due, inSameDayAs: day) else { continue }
            let m = c.component(.hour, from: due) * 60 + c.component(.minute, from: due)
            let who = store.person(forAssignee: t.assignee)
            list.append(Item(minute: m == 0 ? 18 * 60 : m, who: who?.rawValue ?? "À deux", title: t.title, tint: P.person(who), symbol: "checkmark.circle", row: r))
        }
        for r in store.records { if case .event(let e) = r.payload, c.isDate(e.start, inSameDayAs: day) {
            list.append(Item(minute: c.component(.hour, from: e.start) * 60 + c.component(.minute, from: e.start), who: "Rendez-vous", title: e.title, tint: P.sky, symbol: e.sport ? "figure.run" : "calendar", row: r))
        } }
        if let m = store.meal(on: day), let r = store.recipe(m.1.recipeID) {
            list.append(Item(minute: 19 * 60 + 30, who: DuoSchedule.cook(on: day).map { "\($0.rawValue) cuisine" } ?? "À deux", title: (m.1.cooked ? "Mangé · " : "Dîner · ") + r.title, tint: P.butter, symbol: "fork.knife"))
        }
        _ = calBridge.revision
        for ev in calBridge.events(on: day) {
            let m = ev.isAllDay ? 0 : (c.isDate(ev.startDate, inSameDayAs: day) ? c.component(.hour, from: ev.startDate) * 60 + c.component(.minute, from: ev.startDate) : 0)
            let tint: Color = ev.calendar?.cgColor.map { Color(cgColor: $0) } ?? P.sky
            list.append(Item(minute: m, who: ev.calendar?.title ?? "Calendrier", title: ev.title ?? "Rendez-vous", tint: tint, symbol: "calendar", allDay: ev.isAllDay))
        }
        return list.sorted { ($0.allDay ? -1 : $0.minute) < ($1.allDay ? -1 : $1.minute) }
    }
    /// 1.1 : les points du mois sont calculés une seule fois (avant : 2 recherches par case, soit ~70 par affichage).
    private func monthDots() -> (Set<Date>, Set<Date>) {
        let c = cal
        var duo = Set<Date>()
        for r in store.records {
            if case .event(let e) = r.payload { duo.insert(c.startOfDay(for: e.start)) }
            if case .task(let t) = r.payload, t.completed == nil, let d = t.due { duo.insert(c.startOfDay(for: d)) }
        }
        var phone = Set<Date>()
        if calBridge.granted, let end = c.date(byAdding: .month, value: 1, to: month) {
            let evs = calBridge.ek.events(matching: calBridge.ek.predicateForEvents(withStart: month, end: end, calendars: nil))
            for ev in evs { phone.insert(c.startOfDay(for: ev.startDate)) }
        }
        return (duo, phone)
    }
    private var monthDays: [Date?] {
        let c = cal
        guard let range = c.range(of: .day, in: .month, for: month) else { return [] }
        let first = month
        let lead = (c.component(.weekday, from: first) - c.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: lead)
        for d in range { days.append(c.date(byAdding: .day, value: d - 1, to: first)) }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    var body: some View {
        let list = items(on: selected)
        let dots = monthDots()
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Calendrier").kicker()
                        Text(month.formatted(.dateTime.month(.wide).year())).font(P.serif(32)).foregroundStyle(P.text)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Button { shift(-1) } label: { Image(systemName: "chevron.left").frame(width: 40, height: 40) }.accessibilityLabel("Mois précédent")
                        Button { shift(1) } label: { Image(systemName: "chevron.right").frame(width: 40, height: 40) }.accessibilityLabel("Mois suivant")
                    }.foregroundStyle(P.text).padding(.top, 6)
                }

                VStack(spacing: 6) {
                    HStack(spacing: 0) {
                        ForEach(["L", "M", "M", "J", "V", "S", "D"].indices, id: \.self) { i in
                            Text(["L", "M", "M", "J", "V", "S", "D"][i]).font(.system(size: 11, weight: .bold)).foregroundStyle(P.mut).frame(maxWidth: .infinity)
                        }
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                        ForEach(Array(monthDays.enumerated()), id: \.offset) { pair in
                            if let d = pair.element {
                                let on = cal.isDate(d, inSameDayAs: selected)
                                let today = cal.isDateInToday(d)
                                let things = (dots.0.contains(cal.startOfDay(for: d)), dots.1.contains(cal.startOfDay(for: d)))
                                Button { withAnimation(.snappy) { selected = d } } label: {
                                    VStack(spacing: 3) {
                                        Text("\(cal.component(.day, from: d))").font(.system(size: 15, weight: on || today ? .bold : .regular))
                                        HStack(spacing: 3) {
                                            Circle().fill(things.0 ? (on ? P.ink : P.lav) : .clear).frame(width: 5, height: 5)
                                            Circle().fill(things.1 ? (on ? P.ink : P.sky) : .clear).frame(width: 5, height: 5)
                                        }
                                    }
                                    .foregroundStyle(on ? P.ink : (today ? P.lav : P.text))
                                    .frame(maxWidth: .infinity, minHeight: 46)
                                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(on ? P.lav : (today ? P.lav.opacity(0.12) : .clear)))
                                }.buttonStyle(.plain)
                            } else { Color.clear.frame(minHeight: 46) }
                        }
                    }
                }
                .padding(12).glass(24)

                if !calBridge.granted {
                    Button {
                        if calBridge.denied { if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) } }
                        else { Task { await calBridge.request() } }
                    } label: {
                        Label(calBridge.denied ? "Autoriser l'accès au calendrier dans les Réglages" : "Afficher aussi les rendez-vous de mon iPhone", systemImage: "calendar.badge.plus")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(P.sky).frame(maxWidth: .infinity, minHeight: 44)
                    }.glass(16)
                }

                HStack {
                    Text(dayTitle).font(P.serif(23)).foregroundStyle(P.text)
                    Spacer()
                    Button { addEvent = true } label: { Label("Rendez-vous", systemImage: "plus").font(.system(size: 13, weight: .semibold)) }
                        .foregroundStyle(P.ink).padding(.horizontal, 12).frame(minHeight: 36).background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(P.sky))
                }.padding(.top, 4)

                if list.isEmpty {
                    Text("Journée libre. Rien de prévu.").font(.system(size: 14)).foregroundStyle(P.mut).padding(.vertical, 8)
                }
                VStack(spacing: 10) {
                    ForEach(list) { it in
                        HStack(alignment: .top, spacing: 12) {
                            Text(it.allDay ? "Journée" : hm(it.minute)).font(.system(size: 13, weight: .semibold)).foregroundStyle(P.mut).frame(width: 58, alignment: .leading).padding(.top, 14)
                            HStack(spacing: 10) {
                                Image(systemName: it.symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(P.ink).frame(width: 30, height: 30).background(Circle().fill(it.tint))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(it.title).font(.system(size: 15, weight: .medium)).foregroundStyle(P.text).fixedSize(horizontal: false, vertical: true)
                                    Text(it.who).font(.system(size: 11)).foregroundStyle(P.mut)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(it.tint.opacity(0.12)))
                            .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 2).fill(it.tint).frame(width: 3).padding(.vertical, 10) }
                            .contextMenu {
                                if let r = it.row {
                                    Button("Modifier", systemImage: "pencil") { editRow = r }
                                    Button("Supprimer", systemImage: "trash", role: .destructive) { withAnimation { store.remove(r) } }
                                }
                            }
                        }
                    }
                }
                if list.contains(where: { $0.row != nil }) { Text("Appui long sur un rendez-vous ou une tâche pour le modifier ou le supprimer.").font(.system(size: 11)).foregroundStyle(P.mut) }
            }
            .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .refreshable { calBridge.refresh(); await store.sync() }
        .onAppear { calBridge.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in calBridge.refresh() }
        .sheet(isPresented: $addEvent) { NavigationStack { ItemEditor(kind: "event") } }
        .sheet(item: $editRow) { r in NavigationStack { ItemEditor(kind: kindOf(r), row: r) } }
    }
    private var dayTitle: String {
        if cal.isDateInToday(selected) { return "Aujourd'hui" }
        if cal.isDateInTomorrow(selected) { return "Demain" }
        return selected.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
    private func kindOf(_ r: Record) -> String { if case .event = r.payload { return "event" }; return "task" }
    private func shift(_ n: Int) { withAnimation(.snappy) { month = cal.date(byAdding: .month, value: n, to: month) ?? month } }
    private func hm(_ m: Int) -> String { "\(m / 60) h \(String(format: "%02d", m % 60))" }
}

struct DotLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) { configuration.icon.font(.system(size: 7)); configuration.title.foregroundStyle(P.mut) }
    }
}
