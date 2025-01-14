import SwiftUI

struct DateSelectionView: View {
    @Binding var selectedDate: Date
    let viewModel: LakeStationsViewModel
    @EnvironmentObject var scheduleViewModel: ScheduleViewModel
    
    var body: some View {
        HStack {
            if !Calendar.current.isDateInToday(selectedDate) {
                Button(action: {
                    if let newDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) {
                        selectedDate = newDate
                        viewModel.selectedDate = newDate
                        scheduleViewModel.selectedDate = newDate
                        Task {
                            await viewModel.refreshDepartures()
                        }
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Color("text-color"))
                }
            }
            
            HStack {
                Spacer()
                Text(AppDateFormatter.formatDisplayDate(selectedDate))
                    .font(.title3)
                    .foregroundColor(Color("text-color"))
                Spacer()
            }
            .frame(maxWidth: 200)
            
            if let maxDate = Calendar.current.date(byAdding: .day, value: 6, to: Date()),
               selectedDate < maxDate {
                Button(action: {
                    if let newDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) {
                        selectedDate = newDate
                        viewModel.selectedDate = newDate
                        scheduleViewModel.selectedDate = newDate
                        Task {
                            await viewModel.refreshDepartures()
                        }
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color("text-color"))
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
    }
}