import StoreKit

// 添加通知名称扩展
extension Notification.Name {
    static let iapPurchaseSuccess = Notification.Name("iapPurchaseSuccess")
}

class IAPManager: NSObject, SKPaymentTransactionObserver, SKProductsRequestDelegate {
    static let shared = IAPManager()
    var products: [SKProduct] = []  // 初始化为空数组
    var productID: String = "com.mirrorworld.camera.pro"

    // 初始化时开始监听交易
    override init() {
        super.init()
        SKPaymentQueue.default().add(self)
        // 初始化时请求商品信息
        fetchProducts(productIDs: Set([productID]))
    }

    // 请求商品信息
    func fetchProducts(productIDs: Set<String>) {
        let request = SKProductsRequest(productIdentifiers: productIDs)
        request.delegate = self
        request.start()
    }

    // 收到商品信息回调
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        self.products = response.products
        
        // 打印商品信息
        print("------------------------")
        print("[IAP] 获取到商品信息：")
        for product in response.products {
            print("商品ID: \(product.productIdentifier)")
            print("商品名称: \(product.localizedTitle)")
            print("商品价格: \(product.price)")
        }
        if response.products.isEmpty {
            print("[IAP] 未获取到商品信息")
        }
        if !response.invalidProductIdentifiers.isEmpty {
            print("[IAP] 无效的商品ID: \(response.invalidProductIdentifiers)")
        }
        print("------------------------")
    }

    // 发起购买
    func purchase(product: SKProduct) {
        guard SKPaymentQueue.canMakePayments() else {
            print("用户禁止应用内购买")
            return
        }
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }

    // 处理交易结果
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                // 购买成功，解锁内容
                SKPaymentQueue.default().finishTransaction(transaction)
                ProManager.shared.isPro = true  // 更新 Pro 状态
                deliverPurchaseNotification()
            case .failed:
                // 处理失败（如用户取消）
                SKPaymentQueue.default().finishTransaction(transaction)
            case .restored:
                // 恢复购买处理
                SKPaymentQueue.default().finishTransaction(transaction)
                ProManager.shared.isPro = true  // 恢复购买时也更新 Pro 状态
            default:
                break
            }
        }
    }

    // 恢复购买
    func restorePurchases() {
        SKPaymentQueue.default().restoreCompletedTransactions()
    }

    private func deliverPurchaseNotification() {
        NotificationCenter.default.post(name: .iapPurchaseSuccess, object: nil)
    }
}