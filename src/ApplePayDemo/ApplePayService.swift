//
//  ApplePayService.swift
//  ApplePayDemo
//
//  Created by Khachatur Hakobyan on 3/13/20.
//  Copyright © 2020 Wired Mates. All rights reserved.
//

import Foundation
import PassKit

final class ApplePayService: NSObject {
	typealias CanMakePaymentsType = ((Bool) -> Void)?
	typealias UpdateRequestType = ((PKPaymentRequest) -> Void)?
	typealias UpdateShippingMethodsType = (() -> [PKShippingMethod])?
	typealias UpdateSummaryItemsType = ((PKShippingMethod?) -> [PKPaymentSummaryItem])?
	
	private enum PaymentProperty: String {
		case ApplePayMerchantIdentifier
		case ApplePayCurrencyCode
		case ApplePayCountryCode
		case ApplePaySupportedCountries
		
		var value: String! {
			return self.getInfoValueOfBundle(self.rawValue, String.self)
		}
		
		var supportedCountriesValue: Set<String> {
			return Set<String>(self.getInfoValueOfBundle(self.rawValue, [String].self)!)
		}
		
		private func getInfoValueOfBundle<T>(_ key: String, _ valueType: T.Type) -> T? {
			return Bundle.main.infoDictionary![key] as? T
		}
	}
	
	private var canMakePayments: Bool { return PKPaymentAuthorizationController.canMakePayments(usingNetworks: self.paymentNetworks) }
	private let paymentNetworks = [PKPaymentNetwork.visa, .amex, .masterCard, .discover]
	private var updateSummaryItems: UpdateSummaryItemsType = nil
	weak var toViewController: UIViewController? = nil
	
	
	@discardableResult
	func showApplePayViewControllerIfNeeded(canMakePayments: CanMakePaymentsType = nil,
											toViewController: UIViewController? = nil,
											updateRequest: UpdateRequestType = nil,
											updateShippingMethods: UpdateShippingMethodsType = nil,
											updateSummaryItems: UpdateSummaryItemsType = nil) -> UIViewController? {
		let canMakePaymentsRequest = self.canMakePayments
		
		canMakePayments?(canMakePaymentsRequest)
		
		guard canMakePaymentsRequest else { return nil }
		self.toViewController = toViewController
		self.updateSummaryItems = updateSummaryItems
		
		let request = PKPaymentRequest()
		request.currencyCode = PaymentProperty.ApplePayCurrencyCode.value
		request.countryCode = PaymentProperty.ApplePayCountryCode.value
		request.supportedCountries = PaymentProperty.ApplePaySupportedCountries.supportedCountriesValue
		request.merchantIdentifier = PaymentProperty.ApplePayMerchantIdentifier.value
		request.merchantCapabilities = PKMerchantCapability.capability3DS
		request.requiredShippingContactFields = .init(arrayLiteral: .name)
		request.supportedNetworks = self.paymentNetworks
		
		updateRequest?(request)
		
		request.shippingMethods = updateShippingMethods?()
		
		request.paymentSummaryItems = self.updateSummaryItems?(request.shippingMethods?.first) ?? []
		
		let pkPaymentAuthorizationViewController = PKPaymentAuthorizationViewController(paymentRequest: request)
		
		pkPaymentAuthorizationViewController?.delegate = self
		
		if let pkPaymentViewController = pkPaymentAuthorizationViewController {
			toViewController?.show(pkPaymentViewController, sender: nil)
		}
		
		return pkPaymentAuthorizationViewController
	}
}


// MARK: - PKPaymentAuthorizationViewControllerDelegate -

extension ApplePayService: PKPaymentAuthorizationViewControllerDelegate {
	func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController,
											didAuthorizePayment payment: PKPayment,
											handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
		DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
			completion(PKPaymentAuthorizationResult.init(status:.success, errors: nil))
		}
	}
	
	func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
		self.toViewController?.dismiss(animated: true, completion: nil)
	}
	
	func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController,
											didSelect shippingMethod: PKShippingMethod,
											handler completion: @escaping (PKPaymentRequestShippingMethodUpdate) -> Void) {
		completion(.init(paymentSummaryItems: self.updateSummaryItems?(shippingMethod) ?? []))
	}
}
