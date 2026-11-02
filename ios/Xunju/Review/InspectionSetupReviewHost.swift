#if DEBUG
import SwiftUI

struct InspectionSetupReviewHost: View {
    @State private var draft = InspectionTemplateDraft(order: [
        "房源基本信息", "周边与小区", "通风与采光", "隔音与噪音", "墙面地面与门窗", "卫生间", "厨房与水路",
        "卧室与家具收纳", "家电", "虫害鼠害", "电路网络与隐私", "费用与付款", "身份与合同"
    ])
    @State private var mode = InspectionMode.simple
    @State private var finished = false
    @State private var dropTransaction = "未排序"
    @State private var observedOrder: DropOrderObservation = .init()

    var body: some View {
        InspectionSetupSurface(draft: $draft, mode: $mode, conciseWelcome: true) { finished = true }
            .transaction { transaction in
                let previous = observedOrder.value
                observedOrder.value = draft.order
                if let previous, previous != draft.order {
                    let description = transaction.animation == nil ? "无换位动画" : "重复换位动画"
                    DispatchQueue.main.async { dropTransaction = description }
                }
            }
            .overlay(alignment: .topLeading) {
                Text(dropTransaction).font(.system(size: 1)).opacity(0.01).allowsHitTesting(false)
                    .accessibilityIdentifier("setup.review.dropTransaction")
            }
            .alert("组件回调已收到", isPresented: $finished) {
                Button("继续检查", role: .cancel) {}
            } message: {
                Text("\(mode.title)；首项：\(draft.order.first ?? "")。评审草稿未写入房源。")
            }
    }
}

private final class DropOrderObservation {
    var value: [String]?
}
#endif
