import SwiftUI

/// Barra horizontal de filtros da tela Histórico.
struct HistoryFilterBar: View {
    let activeFilters: Set<HistoryFilter>
    let onToggle: (HistoryFilter) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HistoryFilter.allCases) { filter in
                    let isActive = activeFilters.contains(filter)
                    Button {
                        onToggle(filter)
                    } label: {
                        Text(filter.displayName)
                            .font(.footnote.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(isActive ? Color.accentColor : Color.secondary.opacity(0.15))
                            )
                            .foregroundStyle(isActive ? Color.white : Color.primary)
                    }
                    .accessibilityAddTraits(isActive ? [.isSelected] : [])
                }
            }
            .padding(.horizontal)
        }
    }
}
