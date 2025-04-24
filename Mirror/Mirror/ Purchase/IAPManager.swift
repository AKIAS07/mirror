import StoreKit

// 添加通知名称扩展
extension Notification.Name {
    static let iapPurchaseSuccess = Notification.Name("iapPurchaseSuccess")
}

class IAPManager: NSObject, SKPaymentTransactionObserver, SKProductsRequestDelegate {
    static let shared = IAPManager()
    var products: [SKProduct] = []  // 初始化为空数组
    var productID: String = "mira.pro1"
    
    // 添加购买状态检查的回调
    var purchaseStatusCheck: ((Bool) -> Void)?

    // 初始化时开始监听交易
    override init() {
        super.init()
        SKPaymentQueue.default().add(self)
        // 初始化时请求商品信息
        fetchProducts(productIDs: Set([productID]))
        
        // 检查本地存储的购买凭证
        checkLocalReceipt()
    }
    
    // 检查本地购买凭证
    private func checkLocalReceipt() {
        guard let receiptURL = Bundle.main.appStoreReceiptURL,
              FileManager.default.fileExists(atPath: receiptURL.path) else {
            print("------------------------")
            print("[IAP] 本地没有购买凭证")
            print("------------------------")
            return
        }
        
        // 如果发现本地有购买凭证，尝试验证
        do {
            let _ = try Data(contentsOf: receiptURL)
            print("------------------------")
            print("[IAP] 发现本地购买凭证")
            print("------------------------")
            // 如果本地有购买凭证，自动恢复Pro状态
            if UserDefaults.standard.bool(forKey: "HasValidReceipt") {
                ProManager.shared.isPro = true
            }
        } catch {
            print("------------------------")
            print("[IAP] 读取购买凭证失败")
            print("错误：\(error.localizedDescription)")
            print("------------------------")
        }
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
                print("------------------------")
                print("[IAP] 购买成功")
                print("商品ID: \(transaction.payment.productIdentifier)")
                print("------------------------")
                handleSuccessfulTransaction()
                SKPaymentQueue.default().finishTransaction(transaction)
                
            case .failed:
                // 处理失败（如用户取消）
                print("------------------------")
                print("[IAP] 购买失败")
                if let error = transaction.error {
                    print("错误信息: \(error.localizedDescription)")
                }
                print("------------------------")
                SKPaymentQueue.default().finishTransaction(transaction)
                purchaseStatusCheck?(false)
                
            case .restored:
                // 恢复购买处理
                print("------------------------")
                print("[IAP] 恢复购买成功")
                print("商品ID: \(transaction.original?.payment.productIdentifier ?? "未知")")
                print("------------------------")
                handleSuccessfulTransaction()
                SKPaymentQueue.default().finishTransaction(transaction)
                
            case .deferred:
                print("------------------------")
                print("[IAP] 购买延迟")
                print("等待外部操作（如家长同意）")
                print("------------------------")
                
            case .purchasing:
                print("------------------------")
                print("[IAP] 购买进行中")
                print("------------------------")
                
            @unknown default:
                print("------------------------")
                print("[IAP] 未知状态")
                print("------------------------")
                purchaseStatusCheck?(false)
                break
            }
        }
    }

    // 处理成功的交易
    private func handleSuccessfulTransaction() {
        // 更新本地购买状态
        UserDefaults.standard.set(true, forKey: "HasValidReceipt")
        UserDefaults.standard.synchronize()
        
        // 更新Pro状态
        ProManager.shared.isPro = true
        
        // 发送成功通知
        deliverPurchaseNotification()
        
        // 回调状态检查
        purchaseStatusCheck?(true)
    }

    // 恢复购买
    func restorePurchases(completion: ((Bool) -> Void)? = nil) {
        print("------------------------")
        print("[IAP] 开始恢复购买")
        print("------------------------")
        
        // 保存回调
        purchaseStatusCheck = completion
        
        // 如果本地已有有效凭证，直接恢复状态
        if UserDefaults.standard.bool(forKey: "HasValidReceipt") {
            print("[IAP] 发现本地有效凭证，直接恢复状态")
            handleSuccessfulTransaction()
            return
        }
        
        // 否则请求网络恢复
        SKPaymentQueue.default().restoreCompletedTransactions()
    }

    // 处理恢复购买完成
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        print("------------------------")
        print("[IAP] 恢复购买流程完成")
        print("------------------------")
    }
    
    // 处理恢复购买失败
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        print("------------------------")
        print("[IAP] 恢复购买失败")
        print("错误信息: \(error.localizedDescription)")
        print("------------------------")
        purchaseStatusCheck?(false)
    }

    private func deliverPurchaseNotification() {
        NotificationCenter.default.post(name: .iapPurchaseSuccess, object: nil)
    }
}