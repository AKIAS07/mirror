import SwiftUI

struct EdgeDismissOverlay: View {
    let isActive: Bool
    
    var body: some View {
        if isActive {
            Color.clear
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
        }
    }
} 