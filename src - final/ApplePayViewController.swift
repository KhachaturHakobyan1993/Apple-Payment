//
//  ApplePayViewController.swift
//  Swift Academy
//
//  Created by Khachatur Hakobyan on 3/18/20..
//  Copyright © 2020 Swift Academy. All rights reserved.
//

import UIKit
import PassKit

final class ApplePayViewController: UIViewController {
    private let applePayService = ServiceLocator.instance.resolve(IApplePayService.self)!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    
    // MARK: - Private Methods -
    
    private func applePay() {
        self.applePayService.showApplePayViewControllerIfNeeded(productId: .card, canMakePaymentsHandler: { (canMakePayments) in
            debugPrint("ApplePayService|| canMakePayments = \(canMakePayments)")
        }, updateRequest: { (request) in
            debugPrint("ApplePayService|| updateRequest")
        }, updateShippingMethods: { () in
            debugPrint("ApplePayService|| updateShippingMethods")
            return []
        }, updateSummaryItems: nil,
           authorizationViewControllerHandler: { (payVC) in
            debugPrint("ApplePayService|| authorizationViewControllerHandler")
            self.present(payVC!, animated: true, completion: nil)
        }, authorizedPayment: { (payment) in
            debugPrint("ApplePayService|| authorizedPayment = \(payment)")
        }, generatedSTPPaymentMethod: { (stripePaymentMethod, error) in
            debugPrint("ApplePayService|| generatedSTPPaymentMethodId = \(stripePaymentMethod?.stripeId ?? "none"), error = \(error?.localizedDescription ?? "none")")
        }, completionResult: { (result) in
            debugPrint("ApplePayService|| completionResult = \(result.status.rawValue)")
        }) { (payVC) in
            debugPrint("ApplePayService|| finsih")
            payVC.dismiss(animated: true, completion: nil)
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    
    // MARK: - IBAction Methods -
    
    @IBAction private func applePayButtonTapped(_ sender: ApplePayButton) {
        self.applePay()
    }
}
