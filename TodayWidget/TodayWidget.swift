//
//  TodayWidget.swift
//  TodayWidget
//
//  Created by Yang Song on 3/30/23.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []

        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate)
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct TodayWidgetEntryView : View {
    var entry: Provider.Entry
    @State private var image: UIImage? = nil
    @State private var year: String? = nil

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipped()
                } else {
                    Text("No image available")
                }
                
//                VStack(spacing: 0) {
//                    if let year = year {
//                        Text("On this day")
//                            .font(.system(size: 20, weight: .bold))
//                            .foregroundColor(.white)
//                            .shadow(color: .black, radius: 3, x: 0, y: 0)
//                        Text(year)
//                            .font(.system(size: 16, weight: .regular))
//                            .foregroundColor(.white)
//                            .shadow(color: .black, radius: 3, x: 0, y: 0)
//                    }
//                            }
//                            .multilineTextAlignment(.center)
//                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
//                            .padding(.bottom, 4)
                
//
                VStack {
                    Spacer()
                    if let year = year {
                        Text(year)
                            .font(.system(size: 20, weight: .semibold, design: .serif))
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 3, x: 0, y: 0)
                            .padding(EdgeInsets(top: 0, leading: 0, bottom: 38, trailing: 0))
                            .position(x: geometry.size.width / 2, y: geometry.size.height - 20)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                loadImageFromUserDefaults()
            }
            .widgetURL(URL(string: "openToday://widget"))
        }
    }
    
    func loadImageFromUserDefaults() {
        let sharedDefaults = UserDefaults(suiteName: "group.com.YangSong.PhotoFlashBack.Today")
        if let imageData = sharedDefaults?.data(forKey: "randomAssetImageData") {
                image = UIImage(data: imageData)
            }
        if let metadata = sharedDefaults?.dictionary(forKey: "randomAssetMetadata") as? [String: Any],
                   let creationDate = metadata["creationDate"] as? Date {
                    let calendar = Calendar.current
                    let components = calendar.dateComponents([.year], from: creationDate)
                    if let year = components.year {
                        self.year = "On this day\n " + String(year)
                    }
                }
        }
    
    
}

struct TodayWidget: Widget {
    let kind: String = "TodayWidget"
   
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            TodayWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("My Widget")
        .description("This is an example widget.")
    }
}

struct TodayWidget_Previews: PreviewProvider {
    static var previews: some View {
        TodayWidgetEntryView(entry: SimpleEntry(date: Date()))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
