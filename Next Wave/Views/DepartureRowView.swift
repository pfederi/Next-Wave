import SwiftUI

struct DepartureRowView: View {
    let wave: WaveEvent
    let index: Int
    let formattedTime: String
    let isPast: Bool
    let isCurrentDay: Bool
    @ObservedObject var scheduleViewModel: ScheduleViewModel
    
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            TimeColumn(formattedTime: formattedTime, 
                      isPast: isPast, 
                      isCurrentDay: isCurrentDay)
            
            Spacer().frame(width: 16)
            
            InfoColumn(wave: wave, 
                      index: index, 
                      isPast: isPast, 
                      hasNotification: scheduleViewModel.hasNotification(for: wave))
            
            Spacer()
        }
        .id(wave.id)
        .opacity(isPast ? 0.6 : 1.0)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if !isPast && isCurrentDay {
                NotificationButton(wave: wave,
                                 scheduleViewModel: scheduleViewModel,
                                 isCurrentDay: isCurrentDay)
            }
        }
    }
}

private struct TimeColumn: View {
    let formattedTime: String
    let isPast: Bool
    let isCurrentDay: Bool
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(formattedTime)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(isPast ? .gray : .primary)
            if isCurrentDay, let date = DateTimeUtils.parseTime(formattedTime) {
                let remainingTime = DateTimeUtils.calculateRemainingTime(for: date)
                Text(remainingTime)
                    .font(.caption)
                    .foregroundColor(DateTimeUtils.getTimeColor(remainingTime))
                    .padding(.top, 6)
            }
        }
        .frame(width: 70)
    }
}

private struct InfoColumn: View {
    let wave: WaveEvent
    let index: Int
    let isPast: Bool
    let hasNotification: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Image(systemName: "water.waves")
                    .foregroundColor(isPast ? .gray : .blue)
                Text("\(index + 1). Wave")
                    .foregroundColor(isPast ? .gray : .primary)
                
                Spacer()
                
                if hasNotification {
                    Image(systemName: "bell.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 16))
                }
            }
            
            HStack(spacing: 8) {
                Text(wave.routeNumber.replacingOccurrences(of: "^0+", with: "", options: .regularExpression))
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                
                Text("→ \(wave.neighborStopName)")
                    .font(.caption)
                    .foregroundColor(isPast ? .gray : .primary)
            }
        }
    }
}

private struct NotificationButton: View {
    let wave: WaveEvent
    @ObservedObject var scheduleViewModel: ScheduleViewModel
    let isCurrentDay: Bool
    
    var body: some View {
        Button {
            if scheduleViewModel.hasNotification(for: wave) {
                scheduleViewModel.removeNotification(for: wave)
            } else if isCurrentDay {
                scheduleViewModel.scheduleNotification(for: wave)
            }
        } label: {
            Label(scheduleViewModel.hasNotification(for: wave) ? "Remove" : "Notify",
                  systemImage: scheduleViewModel.hasNotification(for: wave) ? "bell.slash" : "bell")
        }
        .tint(scheduleViewModel.hasNotification(for: wave) ? .red : .blue)
        .disabled(!isCurrentDay && !scheduleViewModel.hasNotification(for: wave))
    }
} 