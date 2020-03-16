//
//  ApplePayService.swift
//  ApplePayDemo
//
//  Created by Khachatur Hakobyan on 3/13/20.
//  Copyright © 2020 Wired Mates. All rights reserved.
//

import Foundation
import PassKit
import Stripe

final class ApplePayService: NSObject {
	typealias CanMakePaymentsType = ((Bool) -> Void)?
	typealias UpdateRequestType = ((PKPaymentRequest) -> Void)?
	typealias UpdateShippingMethodsType = (() -> [PKShippingMethod])?
	typealias UpdateSummaryItemsType = ((PKShippingMethod?) -> [PKPaymentSummaryItem])?
	typealias AuthorizationViewControllerHandlerType = ((PKPaymentAuthorizationViewController?) -> Void)?
	typealias AuthorizedPaymentType = ((PKPayment) -> Void)?
	typealias GeneratedSTPTokenType = ((STPToken?, Error?) -> Void)?
	typealias FinishedAuthorizationViewController = ((PKPaymentAuthorizationViewController) -> Void)?
	typealias CompletionResultType = ((PKPaymentAuthorizationResult) -> Void)?
	
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
	private var authorizedPayment: AuthorizedPaymentType = nil
	private var generatedSTPToken: GeneratedSTPTokenType = nil
	private var completionResult: CompletionResultType = nil
	private var finishedAuthorizationViewController: FinishedAuthorizationViewController = nil
	
	
	public func showApplePayViewControllerIfNeeded(canMakePayments: CanMakePaymentsType = nil,
											updateRequest: UpdateRequestType = nil,
											updateShippingMethods: UpdateShippingMethodsType = nil,
											updateSummaryItems: UpdateSummaryItemsType = nil,
											authorizationViewControllerHandler: AuthorizationViewControllerHandlerType = nil,
											authorizedPayment: AuthorizedPaymentType = nil,
											generatedSTPToken: GeneratedSTPTokenType = nil,
											completionResult: CompletionResultType = nil,
											finishedAuthorizationViewController: FinishedAuthorizationViewController = nil) {
		let canMakePaymentsRequest = self.canMakePayments
		
		canMakePayments?(canMakePaymentsRequest)
		
		guard canMakePaymentsRequest else { return }
		
		self.updateSummaryItems = updateSummaryItems
		self.authorizedPayment = authorizedPayment
		self.generatedSTPToken = generatedSTPToken
		self.completionResult = completionResult
		self.finishedAuthorizationViewController = finishedAuthorizationViewController
		
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
		
		authorizationViewControllerHandler?(pkPaymentAuthorizationViewController)
	}
}


// MARK: - PKPaymentAuthorizationViewControllerDelegate -

extension ApplePayService: PKPaymentAuthorizationViewControllerDelegate {
	internal func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController,
											didAuthorizePayment payment: PKPayment,
											handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
		self.authorizedPayment?(payment)
		
		self.generateSTPToken(payment, completion)
	}
	
	internal func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
		self.finishedAuthorizationViewController?(controller)
	}
	
	internal func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController,
											didSelect shippingMethod: PKShippingMethod,
											handler completion: @escaping (PKPaymentRequestShippingMethodUpdate) -> Void) {
		completion(.init(paymentSummaryItems: self.updateSummaryItems?(shippingMethod) ?? []))
	}
}


// MARK: - Generate STPToken -

extension ApplePayService {
	fileprivate func generateSTPToken(_ payment: PKPayment, _ completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
		let errorCompletion: (Error?) -> Void = { [weak self] error in
			let failureResult = PKPaymentAuthorizationResult(status: .failure,
															 errors: error == nil ? nil : [error!])
			completion(failureResult)
			self?.completionResult?(failureResult)
		}
		
		Stripe.setDefaultPublishableKey("pk_test_2R7s5LnhFtBc8yiEAxbuFhXS00NNdySk5S")
		
		STPAPIClient.shared().createToken(with: payment) { [weak self] (stpToken, error) in
			guard let token = stpToken,
				error == nil else {
					self?.generatedSTPToken?(nil, error)
					errorCompletion(error)
					return
			}
			
			self?.generatedSTPToken?(stpToken, nil)
			
			//let shippingAddress = ""//self.createShippingAddressFromRef(payment.shippingAddress)
			
			let url = URL(string: "https://jsonplaceholder.typicode.com/todos/1")!
			var request = URLRequest(url: url)
			request.httpMethod = "GET"
			request.setValue("application/json", forHTTPHeaderField: "Content-Type")
			request.setValue("application/json", forHTTPHeaderField: "Accept")
			
//			let body = ["stripeToken": token.tokenId,
//						"amount": 110,
//						"description": "self.swag!.title",
//						"shipping": [
//							"city": "shippingAddress.City",
//							"state": "shippingAddress.State!",
//							"zip": "shippingAddress.Zip!",
//							"firstName": "shippingAddress.FirstName!",
//							"lastName": "shippingAddress.LastName!" ]
//				] as [String : Any]
//			
//			request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
//			
			URLSession.shared.dataTask(with: request) { [weak self] (data, response, error) in
				guard let _ = data,
					let response = response as? HTTPURLResponse,
					error == nil,
					200..<300 ~= response.statusCode else {
						errorCompletion(error);
						return
				}
				
				let successResult = PKPaymentAuthorizationResult(status: .success, errors: nil)
				completion(successResult)
				self?.completionResult?(successResult)
			}.resume()
		}
	}
}
