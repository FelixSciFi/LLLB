import ActivityKit
import SwiftUI
import WidgetKit

@main
struct LLLBWidgetBundle: WidgetBundle {
    var body: some Widget {
        LLLBWidgetLiveActivity()
        LLLBPlayWidget()
    }
}

// MARK: - Lock screen / home screen play widget

private struct LLLBPlayEntry: TimelineEntry { let date: Date }

private struct LLLBPlayProvider: TimelineProvider {
    func placeholder(in context: Context) -> LLLBPlayEntry { LLLBPlayEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (LLLBPlayEntry) -> Void) {
        completion(LLLBPlayEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<LLLBPlayEntry>) -> Void) {
        completion(Timeline(entries: [LLLBPlayEntry(date: .now)], policy: .never))
    }
}

private struct LLLBPlayWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "play.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
        case .accessoryRectangular:
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .font(.title3)
                    .foregroundStyle(.primary)
                VStack(alignment: .leading, spacing: 1) {
                    Text("LLLB")
                        .font(.headline)
                    Text("点击开始播放")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        default:
            Image(systemName: "play.fill")
                .font(.title2)
        }
    }
}

struct LLLBPlayWidget: Widget {
    let kind = "LLLBPlayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LLLBPlayProvider()) { _ in
            LLLBPlayWidgetView()
                .widgetURL(URL(string: "lllb://play"))
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("LLLB 播放")
        .description("点击立即开始播放")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Live Activity

struct LLLBWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LLLBActivityAttributes.self) { _ in
            EmptyView()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Button(intent: PreviousIntent()) {
                        Image(systemName: "backward.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Button(intent: NextIntent()) {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 8)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 6) {
                        let items: [(Bool, AnyView)] = [
                            (context.state.showImage && !context.state.emoji.isEmpty,
                             AnyView(Text(context.state.emoji).font(.system(size: 44)))),
                            (context.state.showSpelling,
                             AnyView(Text(context.state.text).font(.title3.weight(.semibold)).multilineTextAlignment(.center))),
                            (context.state.showTranslation && !context.state.translation.isEmpty,
                             AnyView(Text(context.state.translation).font(.caption).foregroundStyle(.secondary))),
                            (context.state.showIPA && !context.state.ipa.isEmpty,
                             AnyView(Text("/\(context.state.ipa)/").font(.caption).foregroundStyle(.secondary)))
                        ]
                        let visible = Array(items.filter { $0.0 }.prefix(2))
                        ForEach(Array(visible.enumerated()), id: \.offset) { _, item in
                            item.1
                        }
                        if visible.isEmpty {
                            Text(context.state.text)
                                .font(.title3.weight(.semibold))
                        }
                    }
                    .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Button(intent: PlayPauseIntent()) {
                        Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 8)
                }
            } compactLeading: {
                Text(context.state.emoji.isEmpty ? "🎵" : context.state.emoji)
                    .font(.body)
            } compactTrailing: {
                Image(systemName: context.state.isPlaying ? "waveform" : "pause")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } minimal: {
                Text(context.state.emoji.isEmpty ? "🎵" : context.state.emoji)
            }
        }
    }
}
