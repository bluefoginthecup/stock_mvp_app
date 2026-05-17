import SwiftUI
import WidgetKit

private let appGroupId = "group.com.bluefog.chalstock"

struct TodayScheduleEntry: TimelineEntry {
    let date: Date
    let payload: TodaySchedulePayload
}

struct TodaySchedulePayload: Decodable {
    let dateLabel: String
    let updatedAtLabel: String
    let pendingCount: Int
    let doneCount: Int
    let schedules: [TodayScheduleItem]

    static let placeholder = TodaySchedulePayload(
        dateLabel: "오늘 일정",
        updatedAtLabel: "--:--",
        pendingCount: 0,
        doneCount: 0,
        schedules: []
    )

    static func from(dictionary: [String: Any]) -> TodaySchedulePayload {
        let scheduleValues = dictionary["schedules"] as? [[String: Any]] ?? []
        let items = scheduleValues.map { value in
            TodayScheduleItem(
                id: value["id"] as? String ?? UUID().uuidString,
                title: value["title"] as? String ?? "",
                body: value["body"] as? String ?? "",
                status: value["status"] as? String ?? "pending",
                isPinned: value["isPinned"] as? Bool ?? false
            )
        }.filter { !$0.title.isEmpty }

        return TodaySchedulePayload(
            dateLabel: dictionary["dateLabel"] as? String ?? "오늘 일정",
            updatedAtLabel: dictionary["updatedAtLabel"] as? String ?? "--:--",
            pendingCount: dictionary["pendingCount"] as? Int ?? 0,
            doneCount: dictionary["doneCount"] as? Int ?? 0,
            schedules: items
        )
    }
}

struct TodayScheduleItem: Decodable, Identifiable {
    let id: String
    let title: String
    let body: String
    let status: String
    let isPinned: Bool
}

struct TodayScheduleProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayScheduleEntry {
        TodayScheduleEntry(date: Date(), payload: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayScheduleEntry) -> Void) {
        completion(TodayScheduleEntry(date: Date(), payload: loadPayload()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayScheduleEntry>) -> Void) {
        let entry = TodayScheduleEntry(date: Date(), payload: loadPayload())
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadPayload() -> TodaySchedulePayload {
        if
            let containerUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId),
            let data = try? Data(contentsOf: containerUrl.appendingPathComponent("todaySchedules.json")),
            let payload = decodePayload(from: data)
        {
            return payload
        }

        if
            let defaults = UserDefaults(suiteName: appGroupId),
            let json = defaults.string(forKey: "todaySchedulesJson"),
            let data = json.data(using: .utf8),
            let payload = decodePayload(from: data)
        {
            return payload
        }

        return .placeholder
    }

    private func decodePayload(from data: Data) -> TodaySchedulePayload? {
        if let payload = try? JSONDecoder().decode(TodaySchedulePayload.self, from: data) {
            return payload
        }
        if
            let object = try? JSONSerialization.jsonObject(with: data),
            let dictionary = object as? [String: Any]
        {
            return TodaySchedulePayload.from(dictionary: dictionary)
        }
        return nil
    }
}

struct TodayScheduleWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayScheduleEntry

    var body: some View {
        let isLarge = family == .systemLarge
        let visibleCount = isLarge ? 8 : 3

        VStack(alignment: .leading, spacing: isLarge ? 12 : 10) {
            HStack(alignment: .center) {
                Link(destination: URL(string: "chalstock://schedules/today")!) {
                    Text(entry.payload.dateLabel)
                        .font(.headline.weight(.bold))
                        .lineLimit(1)
                }
                .buttonStyle(.plain)

                Spacer()

                WidgetActionButton(
                    label: "할일",
                    systemImage: "checklist",
                    url: URL(string: "chalstock://schedules/new")!
                )
                WidgetActionButton(
                    label: "메모",
                    systemImage: "note.text",
                    url: URL(string: "chalstock://memo")!
                )
                WidgetActionButton(
                    label: "재고",
                    systemImage: "shippingbox",
                    url: URL(string: "chalstock://stock")!
                )
            }

            HStack(spacing: 8) {
                Link(destination: URL(string: "chalstock://schedules/today")!) {
                    CountPill(label: "할일", count: entry.payload.pendingCount, color: .purple)
                    CountPill(label: "완료", count: entry.payload.doneCount, color: .green)
                }
                .buttonStyle(.plain)
                Spacer()
                Text("업데이트 \(entry.payload.updatedAtLabel)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if entry.payload.schedules.isEmpty {
                Spacer(minLength: 0)
                Link(destination: URL(string: "chalstock://schedules/new")!) {
                    Label("오늘 일정을 추가하세요", systemImage: "calendar.badge.plus")
                        .font(.subheadline.weight(.semibold))
                }
                Spacer(minLength: 0)
            } else {
                VStack(alignment: .leading, spacing: isLarge ? 8 : 6) {
                    ForEach(entry.payload.schedules.prefix(visibleCount)) { item in
                        Link(destination: URL(string: "chalstock://schedules/detail?id=\(item.id)")!) {
                            ScheduleRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                    if entry.payload.schedules.count > visibleCount {
                        Text("+\(entry.payload.schedules.count - visibleCount)개 더")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                }
            }
        }
        .padding()
        .widgetURL(URL(string: "chalstock://home"))
        .chalstockWidgetBackground()
    }
}

private extension View {
    @ViewBuilder
    func chalstockWidgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(.background, for: .widget)
        } else {
            self.background(Color(.systemBackground))
        }
    }
}

struct WidgetActionButton: View {
    let label: String
    let systemImage: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            Label(label, systemImage: systemImage)
                .font(.caption.weight(.bold))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .foregroundStyle(.primary)
                .background(Color(.tertiarySystemFill), in: Capsule())
        }
        .accessibilityLabel(label)
    }
}

struct CountPill: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        Text("\(label) \(count)")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: Capsule())
    }
}

struct ScheduleRow: View {
    let item: TodayScheduleItem

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Image(systemName: item.status == "done" ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundStyle(item.status == "done" ? .green : .purple)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                    }
                    Text(item.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                if !item.body.isEmpty {
                    Text(item.body)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

@main
struct TodayScheduleWidget: Widget {
    let kind = "TodayScheduleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayScheduleProvider()) { entry in
            TodayScheduleWidgetView(entry: entry)
        }
        .configurationDisplayName("찰스톡 오늘 일정")
        .description("오늘의 일정과 할일을 확인하고 새 일정을 빠르게 추가합니다.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
