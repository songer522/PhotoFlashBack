//
//  TodayWidget.swift
//  TodayWidget
//
//  Created by Yang Song on 3/30/23.
//

import WidgetKit
import SwiftUI

// MARK: - Widget Entry
struct MemoryEntry: TimelineEntry {
    let date: Date
    let memories: [MemoryPhoto]
    let isEmpty: Bool
    
    struct MemoryPhoto: Identifiable {
        let id = UUID()
        let image: UIImage
        let year: String
        let creationDate: Date
        let localIdentifier: String
        let widgetIndex: Int
    }

    /// Per-photo deep link so a tap opens the exact card that was tapped,
    /// not always the first stored asset. Matches WidgetDeepLink in the app
    /// target (duplicated here because the widget can't see app sources).
    static func widgetURL(index: Int, localIdentifier: String) -> URL {
        var components = URLComponents()
        components.scheme = "openToday"
        components.host = "widget"
        components.queryItems = [
            URLQueryItem(name: "index", value: String(index)),
            URLQueryItem(name: "localId", value: localIdentifier),
        ]
        return components.url ?? URL(string: "openToday://widget")!
    }
    
    static var placeholder: MemoryEntry {
        MemoryEntry(date: Date(), memories: [], isEmpty: true)
    }
}

// MARK: - Timeline Provider
struct MemoryTimelineProvider: TimelineProvider {
    typealias Entry = MemoryEntry
    
    func placeholder(in context: Context) -> MemoryEntry {
        .placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (MemoryEntry) -> Void) {
        let entry = loadMemories(for: Date(), context: context)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<MemoryEntry>) -> Void) {
        let currentDate = Date()
        let entry = loadMemories(for: currentDate, context: context)
        
        // Update at midnight tomorrow
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: currentDate)!)
        
        let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
        completion(timeline)
    }
    
    private func loadMemories(for date: Date, context: Context) -> MemoryEntry {
        let sharedDefaults = UserDefaults(suiteName: "group.com.YangSong.PhotoFlashBack.Today")
        
        // Determine how many photos to load based on widget size
        let maxPhotos: Int
        switch context.family {
        case .systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline:
            maxPhotos = 1
        case .systemMedium:
            maxPhotos = 3
        case .systemLarge, .systemExtraLarge:
            maxPhotos = 6
        @unknown default:
            maxPhotos = 1
        }
        
        var memories: [MemoryEntry.MemoryPhoto] = []
        let calendar = Calendar.current
        let todayComponents = calendar.dateComponents([.day, .month], from: date)

        // Load photos from shared storage
        for index in 0..<maxPhotos {
            let imageKey = index == 0 ? "randomAssetImageData" : "randomAssetImageData_\(index)"
            let metadataKey = index == 0 ? "randomAssetMetadata" : "randomAssetMetadata_\(index)"

            if let imageData = sharedDefaults?.data(forKey: imageKey),
               let image = UIImage(data: imageData),
               let metadata = sharedDefaults?.dictionary(forKey: metadataKey) as? [String: Any],
               let creationDate = metadata["creationDate"] as? Date,
               let localIdentifier = metadata["localIdentifier"] as? String {

                // Skip stale entries left over from a previous day's fetch that don't
                // actually match today's day/month, so old "on this day" photos don't linger.
                let storedComponents = calendar.dateComponents([.day, .month], from: creationDate)
                guard storedComponents.day == todayComponents.day,
                      storedComponents.month == todayComponents.month else {
                    continue
                }

                let year = Calendar.current.component(.year, from: creationDate)
                let memory = MemoryEntry.MemoryPhoto(
                    image: image,
                    year: String(year),
                    creationDate: creationDate,
                    localIdentifier: localIdentifier,
                    widgetIndex: index
                )
                memories.append(memory)
            }
        }
        
        return MemoryEntry(
            date: date,
            memories: memories,
            isEmpty: memories.isEmpty
        )
    }
}

// MARK: - Widget Views
struct TodayWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: MemoryEntry
    
    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(entry: entry)
            case .systemMedium:
                MediumWidgetView(entry: entry)
            case .systemLarge, .systemExtraLarge:
                LargeWidgetView(entry: entry)
            case .accessoryCircular:
                CircularWidgetView(entry: entry)
            case .accessoryRectangular:
                RectangularWidgetView(entry: entry)
            case .accessoryInline:
                InlineWidgetView(entry: entry)
            @unknown default:
                SmallWidgetView(entry: entry)
            }
        }
    }
}

// MARK: - Small Widget
struct SmallWidgetView: View {
    let entry: MemoryEntry
    
    var body: some View {
        if entry.isEmpty {
            EmptyStateView()
        } else if let memory = entry.memories.first {
            Link(destination: MemoryEntry.widgetURL(index: memory.widgetIndex, localIdentifier: memory.localIdentifier)) {
                GeometryReader { geometry in
                    ZStack(alignment: .bottomLeading) {
                        Image(uiImage: memory.image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()

                        LinearGradient(
                            colors: [.clear, .black.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("On this day")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.9))

                            Text(memory.year)
                                .font(.title2.bold())
                                .foregroundColor(.white)
                        }
                        .padding(12)
                    }
                }
            }
            .id(memory.year) // Prevent animation glitch when switching sizes
        } else {
            LoadingStateView()
        }
    }
}

// MARK: - Medium Widget
struct MediumWidgetView: View {
    let entry: MemoryEntry
    
    var body: some View {
        if entry.isEmpty {
            EmptyStateView()
        } else {
            HStack(spacing: 2) {
                ForEach(entry.memories.prefix(3)) { memory in
                    Link(destination: MemoryEntry.widgetURL(index: memory.widgetIndex, localIdentifier: memory.localIdentifier)) {
                        MemoryCardView(memory: memory)
                    }
                }
            }
            .padding(2)
        }
    }
}

// MARK: - Large Widget
struct LargeWidgetView: View {
    let entry: MemoryEntry
    
    var body: some View {
        if entry.isEmpty {
            EmptyStateView()
        } else {
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    ForEach(entry.memories.prefix(3)) { memory in
                        Link(destination: MemoryEntry.widgetURL(index: memory.widgetIndex, localIdentifier: memory.localIdentifier)) {
                            MemoryCardView(memory: memory)
                        }
                    }
                }

                if entry.memories.count > 3 {
                    HStack(spacing: 2) {
                        ForEach(entry.memories.dropFirst(3).prefix(3)) { memory in
                            Link(destination: MemoryEntry.widgetURL(index: memory.widgetIndex, localIdentifier: memory.localIdentifier)) {
                                MemoryCardView(memory: memory)
                            }
                        }
                    }
                }
            }
            .padding(2)
        }
    }
}

// MARK: - Lock Screen Widgets
struct CircularWidgetView: View {
    let entry: MemoryEntry
    
    var body: some View {
        if let memory = entry.memories.first {
            Link(destination: MemoryEntry.widgetURL(index: memory.widgetIndex, localIdentifier: memory.localIdentifier)) {
                ZStack {
                    Image(uiImage: memory.image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)

                    Circle()
                        .fill(Color.black.opacity(0.3))
                        .overlay {
                            Text(memory.year)
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }
                }
                .clipShape(Circle())
            }
        } else {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.title2)
        }
    }
}

struct RectangularWidgetView: View {
    let entry: MemoryEntry
    
    var body: some View {
        if let memory = entry.memories.first {
            Link(destination: MemoryEntry.widgetURL(index: memory.widgetIndex, localIdentifier: memory.localIdentifier)) {
                HStack(spacing: 8) {
                    Image(uiImage: memory.image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Memory")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text(memory.year)
                            .font(.headline)
                    }

                    Spacer()
                }
            }
        } else {
            HStack {
                Image(systemName: "photo")
                Text("No memories")
                    .font(.caption)
            }
        }
    }
}

struct InlineWidgetView: View {
    let entry: MemoryEntry
    
    var body: some View {
        if let memory = entry.memories.first {
            Link(destination: MemoryEntry.widgetURL(index: memory.widgetIndex, localIdentifier: memory.localIdentifier)) {
                Text("Memory from \(memory.year)")
            }
        } else {
            Text("No memories today")
        }
    }
}

// MARK: - Helper Views
struct MemoryCardView: View {
    let memory: MemoryEntry.MemoryPhoto
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                Image(uiImage: memory.image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                
                LinearGradient(
                    colors: [.clear, .black.opacity(0.6)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                
                Text(memory.year)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(8)
            }
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.title)
                .foregroundColor(.secondary)
            
            Text("No memories")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("for this day")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

struct LoadingStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading memories...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Widget Configuration
struct TodayWidget: Widget {
    let kind: String = "TodayWidget"
   
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MemoryTimelineProvider()) { entry in
            if #available(iOS 17.0, *) {
                TodayWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        Color.clear
                    }
            } else {
                TodayWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("Rewind: Today's Memories")
        .description("Rediscover photos taken on this day in previous years")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
        .contentMarginsDisabled()
    }
}

// MARK: - Previews
struct TodayWidget_Previews: PreviewProvider {
    static let sampleMemories = [
        MemoryEntry.MemoryPhoto(
            image: UIImage(systemName: "photo")!,
            year: "2019",
            creationDate: Date(),
            localIdentifier: "preview-0",
            widgetIndex: 0
        ),
        MemoryEntry.MemoryPhoto(
            image: UIImage(systemName: "photo.fill")!,
            year: "2015",
            creationDate: Date(),
            localIdentifier: "preview-1",
            widgetIndex: 1
        ),
        MemoryEntry.MemoryPhoto(
            image: UIImage(systemName: "photo.circle")!,
            year: "2012",
            creationDate: Date(),
            localIdentifier: "preview-2",
            widgetIndex: 2
        )
    ]
    
    static var previews: some View {
        Group {
            // Small widget
            TodayWidgetEntryView(entry: MemoryEntry(
                date: Date(),
                memories: Array(sampleMemories.prefix(1)),
                isEmpty: false
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Small Widget")
            
            // Medium widget
            TodayWidgetEntryView(entry: MemoryEntry(
                date: Date(),
                memories: sampleMemories,
                isEmpty: false
            ))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .previewDisplayName("Medium Widget")
            
            // Large widget
            TodayWidgetEntryView(entry: MemoryEntry(
                date: Date(),
                memories: sampleMemories + sampleMemories,
                isEmpty: false
            ))
            .previewContext(WidgetPreviewContext(family: .systemLarge))
            .previewDisplayName("Large Widget")
            
            // Lock Screen - Circular
            TodayWidgetEntryView(entry: MemoryEntry(
                date: Date(),
                memories: Array(sampleMemories.prefix(1)),
                isEmpty: false
            ))
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
            .previewDisplayName("Lock Screen - Circular")
            
            // Lock Screen - Rectangular
            TodayWidgetEntryView(entry: MemoryEntry(
                date: Date(),
                memories: Array(sampleMemories.prefix(1)),
                isEmpty: false
            ))
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
            .previewDisplayName("Lock Screen - Rectangular")
            
            // Empty state
            TodayWidgetEntryView(entry: MemoryEntry(
                date: Date(),
                memories: [],
                isEmpty: true
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Empty State")
        }
    }
}

