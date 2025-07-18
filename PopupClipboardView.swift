import SwiftUI

struct PopupClipboardView: View {
    var history: [String]
    var onSelect: (String) -> Void

    @State private var selectedIndex = 0
    @State private var eventMonitor: Any?


    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Clipboard History")
                .font(.headline)
                .padding()

            List(0..<history.count, id: \.self) { i in
                Text(history[i])
                    .lineLimit(1)
                    .padding(4)
                    .background(i == selectedIndex ? Color.accentColor.opacity(0.2) : Color.clear)
            }
            .listStyle(PlainListStyle())
            .frame(maxHeight: .infinity)
        }
        .frame(width: 400, height: 300)
        .onAppear {
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                switch event.keyCode {
                case 125: // ↓
                    selectedIndex = min(selectedIndex + 1, history.count - 1)
                    return nil
                case 126: // ↑
                    selectedIndex = max(selectedIndex - 1, 0)
                    return nil
                case 36: // Enter
                    onSelect(history[selectedIndex])
                    return nil
                case 53: // ESC
                    NSApp.keyWindow?.close()
                    return nil
                default:
                    return event
                }
            }

        }
        .onDisappear {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
        }
    }
}

