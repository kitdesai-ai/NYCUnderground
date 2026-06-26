import WidgetKit
import SwiftUI

@main
struct NYCUndergroundWidgetBundle: WidgetBundle {
    var body: some Widget {
        StationArrivalsWidget()
    }
}

struct StationArrivalsWidget: Widget {
    static let kind = "StationArrivalsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: StationArrivalsProvider()) { entry in
            StationArrivalsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Next Trains")
        .description("Live arrivals for your nearest subway station.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
