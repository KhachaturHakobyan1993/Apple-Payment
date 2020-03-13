//
//  ViewController.swift
//  ApplePayDemo
//
//  Created by Khachatur Hakobyan on 3/13/20.
//  Copyright © 2020 Wired Mates. All rights reserved.
//

import UIKit
import PassKit

final class ViewController: UIViewController {
	private let applePayService = ApplePayService()
	
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.setup()
	}
	
	private func setup() {
		let applePayButton = PKPaymentButton(paymentButtonType: .subscribe, paymentButtonStyle: .black)
		applePayButton.addTarget(self, action: #selector(self.applePayButtonTapped), for: .touchUpInside)
		applePayButton.frame = .init(x: 0, y: 0, width: 200, height: 44)
		applePayButton.center = self.view.center
		self.view.addSubview(applePayButton)
	}
	
	@objc private func applePayButtonTapped() {
		self.applePayService.showApplePayViewControllerIfNeeded(canMakePayments: { (canMakePayment) in
			print("canMakePayment = \(canMakePayment)")
		},toViewController: self,
		  updateRequest: { (request) in
			print("updateRequest")
		}, updateShippingMethods: { () -> [PKShippingMethod] in
			print("updateShippingMethods")
			return []
		}) { (method) -> [PKPaymentSummaryItem] in
			
			print("PaymentSummaryItem")
			return [.init(label: "Total", amount: 340)]
		}
	}
}

