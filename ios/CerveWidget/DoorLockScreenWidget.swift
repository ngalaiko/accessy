import AppIntents
import SwiftUI
import WidgetKit

struct DoorWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Door"
    static var description: IntentDescription = "Choose a door to unlock"

    @Parameter(title: "Door")
    var door: DoorEntity?
}

struct DoorLockScreenProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DoorLockScreenEntry {
        DoorLockScreenEntry(date: .now, doorId: nil, doorName: "Door")
    }

    func snapshot(for configuration: DoorWidgetConfigurationIntent, in context: Context) async -> DoorLockScreenEntry {
        DoorLockScreenEntry(date: .now, doorId: configuration.door?.id, doorName: configuration.door?.name ?? "Door")
    }

    func timeline(for configuration: DoorWidgetConfigurationIntent, in context: Context) async -> Timeline<DoorLockScreenEntry> {
        let entry = DoorLockScreenEntry(date: .now, doorId: configuration.door?.id, doorName: configuration.door?.name ?? "Door")
        return Timeline(entries: [entry], policy: .never)
    }
}

struct DoorLockScreenEntry: TimelineEntry {
    let date: Date
    let doorId: String?
    let doorName: String
}

struct DoorLockScreenView: View {
    let entry: DoorLockScreenEntry

    var body: some View {
        if let doorId = entry.doorId {
            Button(intent: UnlockDoorIntent(doorId: doorId)) {
                VStack(spacing: 2) {
                    Image(systemName: "door.left.hand.open")
                        .font(.system(size: 20))
                    Text(entry.doorName)
                        .font(.system(size: 8))
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)
        } else {
            VStack(spacing: 2) {
                Image(systemName: "door.left.hand.closed")
                    .font(.system(size: 20))
                Text("Select")
                    .font(.system(size: 8))
            }
        }
    }
}

struct DoorLockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "DoorLockScreenWidget",
            intent: DoorWidgetConfigurationIntent.self,
            provider: DoorLockScreenProvider()
        ) { entry in
            DoorLockScreenView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Door Unlock")
        .description("Tap to unlock a door.")
        .supportedFamilies([.accessoryCircular])
    }
}
