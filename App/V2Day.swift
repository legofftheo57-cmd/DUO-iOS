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

/// La journée en ruban 3D : chaque moment bascule en perspective autour de la ligne « maintenant ».
struct DayV2: View {
    @Environment(AppStore.self) private var store
    @State private var selected = Calendar.current.startOfDay(for: Date())
    @State private var topID: Int?
    @State private var picking = false
    @State private var calBridge = CalendarBridge.shared

    struct Moment: Identifiable { let id: Int; let minute: Int; let who: String; let title: String; let tint: Color }

    private var day: Date { selected }
    private var isToday: Bool { Calendar.current.isDateInToday(selected) }
    private var dayTitle: String {
        let c = Calendar.current
        if c.isDateInToday(selected) { return "Aujourd'hui" }
        if c.isDateInTomorrow(selected) { return "Demain" }
        return selected.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    private var moments: [Moment] {
        var list: [Moment] = []
        var n = 0
        func add(_ m: Int, _ who: String, _ t: String, _ c: Color) { list.append(Moment(id: n, minute: m, who: who, title: t, tint: c)); n += 1 }
        for p in DuoPerson.allCases {
            if let w = DuoSchedule.work(p, on: day) {
                add(w.start, p.rawValue, w.label, P.person(p))
                add(w.end, p.rawValue, "Fin · libre vers \(hm(w.end + 30))", P.person(p))
            }
        }
        let cal = Calendar.current
        for (_, t) in store.taskRows where t.completed == nil {
            guard let due = t.due, cal.isDate(due, inSameDayAs: day) else { continue }
            let who = store.person(forAssignee: t.assignee)
            let m = cal.component(.hour, from: due) * 60 + cal.component(.minute, from: due)
            add(m == 0 ? 18 * 60 : m, who?.rawValue ?? "Ensemble", t.title, P.person(who))
        }
        for r in store.records { if case .event(let e) = r.payload, cal.isDate(e.start, inSameDayAs: day) {
            add(cal.component(.hour, from: e.start) * 60 + cal.component(.minute, from: e.start), "Agenda", e.title, P.sky)
        } }
        _ = calBridge.revision
        for ev in calBridge.events(on: day) {
            let m = ev.isAllDay ? 7 * 60 : (Calendar.current.isDate(ev.startDate, inSameDayAs: day) ? Calendar.current.component(.hour, from: ev.startDate) * 60 + Calendar.current.component(.minute, from: ev.startDate) : 0)
            let tint: Color = ev.calendar?.cgColor.map { Color(cgColor: $0) } ?? P.sky
            add(m, ev.calendar?.title ?? "Calendrier", (ev.isAllDay ? "Toute la journée · " : "") + (ev.title ?? "Rendez-vous"), tint)
        }
        if let m = store.meal(on: day), let r = store.recipe(m.1.recipeID) {
            add(19 * 60 + 30, "Ensemble", (m.1.cooked ? "Mangé · " : "Dîner · ") + r.title, P.mint)
            if let cook = DuoSchedule.cook(on: day) { add(18 * 60 + 45, cook.rawValue, "Préparer le dîner", P.person(cook)) }
        }
        if DuoSchedule.work(.theo, on: day.addingTimeInterval(86400))?.start ?? 9999 < 6 * 60 { add(22 * 60, "Théo", "Dodo · réveil 4 h 40 demain", P.lav) }
        return list.sorted { $0.minute < $1.minute }.enumerated().map { Moment(id: $0.offset, minute: $0.element.minute, who: $0.element.who, title: $0.element.title, tint: $0.element.tint) }
    }

    var body: some View {
        let items = moments
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(dayTitle + (isToday ? " · fais défiler" : "")).kicker()
                    Spacer()
                    Button { picking = true } label: { Label("Calendrier", systemImage: "calendar").font(.system(size: 12, weight: .semibold)) }
                        .foregroundStyle(P.lav).frame(minHeight: 36)
                }
                Text(items.first(where: { $0.id == (topID ?? 0) }).map { hm($0.minute) } ?? "Rien de prévu").font(P.serif(32)).foregroundStyle(P.text)
                    .contentTransition(.numericText())
                HStack(spacing: 12) {
                    Label("Théo", systemImage: "circle.fill").foregroundStyle(P.lav)
                    Label("Lilou", systemImage: "circle.fill").foregroundStyle(P.peach)
                    Label("Ensemble", systemImage: "circle.fill").foregroundStyle(P.mint)
                    Spacer()
                }.font(.system(size: 12)).labelStyle(DotLabel())
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(0..<21, id: \.self) { i in
                            let d = Calendar.current.date(byAdding: .day, value: i, to: Calendar.current.startOfDay(for: Date())) ?? Date()
                            let on = Calendar.current.isDate(d, inSameDayAs: selected)
                            Button { withAnimation(.snappy) { selected = d } } label: {
                                VStack(spacing: 2) {
                                    Text(d.formatted(.dateTime.weekday(.abbreviated))).font(.system(size: 10, weight: .bold)).opacity(0.7)
                                    Text("\(Calendar.current.component(.day, from: d))").font(.system(size: 15, weight: .semibold))
                                }
                                .foregroundStyle(on ? P.ink : P.text)
                                .frame(width: 46, height: 52)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(on ? P.lav : Color.white.opacity(0.05)))
                            }.buttonStyle(.plain)
                        }
                    }
                }
                if !calBridge.granted {
                    Button {
                        if calBridge.denied { if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) } }
                        else { Task { await calBridge.request() } }
                    } label: {
                        Label(calBridge.denied ? "Autoriser l'accès au calendrier dans les Réglages" : "Afficher les rendez-vous de mon calendrier iPhone", systemImage: "calendar.badge.plus")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(P.lav).frame(minHeight: 40)
                    }
                }
            }.padding(.horizontal, 20).padding(.top, 8)

            GeometryReader { outer in
                let center = outer.size.height * 0.38
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(items) { m in
                            MomentCard(m: m)
                                .visualEffect { content, proxy in
                                    let mid = proxy.frame(in: .scrollView).midY
                                    let a = max(-1, min(1, (mid - center) / 260))
                                    return content
                                        .rotation3DEffect(.degrees(-a * 50), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
                                        .scaleEffect(1 - abs(a) * 0.08)
                                        .opacity(1 - abs(a) * 0.5)
                                }
                                .id(m.id)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, 18).padding(.top, center - 40).padding(.bottom, outer.size.height - center)
                }
                .scrollPosition(id: $topID, anchor: .init(x: 0.5, y: 0.38))
                .scrollIndicators(.hidden)
                .overlay(alignment: .top) {
                    Rectangle().fill(LinearGradient(colors: [.clear, P.lav, .clear], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 1).shadow(color: P.lav, radius: 8).offset(y: center).allowsHitTesting(false)
                }
            }
        }
        .onChange(of: selected) { _, _ in topID = 0 }
        .onAppear { calBridge.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in calBridge.refresh() }
        .sheet(isPresented: $picking) {
            NavigationStack {
                DatePicker("Jour", selection: $selected, displayedComponents: [.date])
                    .datePickerStyle(.graphical).padding()
                    .navigationTitle("Choisir un jour")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) { Button("OK") { selected = Calendar.current.startOfDay(for: selected); picking = false } }
                        ToolbarItem(placement: .cancellationAction) { Button("Aujourd'hui") { selected = Calendar.current.startOfDay(for: Date()); picking = false } }
                    }
            }.presentationDetents([.medium, .large])
        }
    }
    private func hm(_ m: Int) -> String { "\(m / 60) h \(String(format: "%02d", m % 60))" }

    struct MomentCard: View {
        let m: Moment
        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack { Text(m.who); Spacer(); Text("\(m.minute / 60) h \(String(format: "%02d", m.minute % 60))") }
                    .font(.system(size: 11, weight: .bold)).opacity(0.7)
                Text(m.title).font(P.serif(19)).multilineTextAlignment(.leading)
            }
            .foregroundStyle(P.ink).padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(LinearGradient(colors: [m.tint, m.tint.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)))
            .accessibilityElement(children: .combine)
        }
    }
}

struct DotLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) { configuration.icon.font(.system(size: 7)); configuration.title.foregroundStyle(P.mut) }
    }
}
