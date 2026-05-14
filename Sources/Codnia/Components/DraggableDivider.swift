import SwiftUI

struct DraggableDivider: View {
    @Binding var value: CGFloat
    var minValue: CGFloat
    var maxValue: CGFloat

    var body: some View {
        HorizontalResizableDivider(height: $value, minHeight: minValue, maxHeight: maxValue)
    }
}
