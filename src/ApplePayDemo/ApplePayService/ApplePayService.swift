//
//  ApplePayService.swift
//  Wiredmates
//
//  Created by Khachatur Hakobyan on 3/16/20.
//  Copyright © 2020 Wiredmates. All rights reserved.
//

import Foundation
import PassKit
import Stripe

internal final class ApplePayService: NSObject, IApplePayService {
    fileprivate let apiService: IWMApiService
	private var productId: PaymentProductIds!
    private var canMakePayments: Bool { return PKPaymentAuthorizationController.canMakePayments(usingNetworks: self.paymentNetworks) }
    private let paymentNetworks = [PKPaymentNetwork.visa, .amex, .masterCard, .discover]
    private var updateSummaryItems: UpdateSummaryItemsType = nil
    private var authorizedPayment: AuthorizedPaymentType = nil
    private var generatedSTPToken: GeneratedSTPTokenType = nil
    private var completionResult: CompletionResultType = nil
    private var finishedAuthorizationViewController: FinishedAuthorizationViewController = nil
    
    
    init(_ apiService: IWMApiService) {
        self.apiService = apiService
    }
    
	func showApplePayViewControllerIfNeeded(productId: PaymentProductIds,
											canMakePayments: CanMakePaymentsType = nil,
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
        
		self.productId = productId
        self.updateSummaryItems = updateSummaryItems
        self.authorizedPayment = authorizedPayment
        self.generatedSTPToken = generatedSTPToken
        self.completionResult = completionResult
        self.finishedAuthorizationViewController = finishedAuthorizationViewController
        
        let request = PKPaymentRequest()
		request.currencyCode = Bundle.InfoPlistKeys.ApplePayment.ApplePayCurrencyCode.value
        request.countryCode = Bundle.InfoPlistKeys.ApplePayment.ApplePayCountryCode.value
        request.supportedCountries = Bundle.InfoPlistKeys.ApplePayment.ApplePaySupportedCountries.supportedCountriesValue
		request.merchantIdentifier = Bundle.InfoPlistKeys.ApplePayment.ApplePayMerchantIdentifier.value
        request.merchantCapabilities = PKMerchantCapability.capability3DS
        request.requiredShippingContactFields = .init(arrayLiteral: .name)
        request.supportedNetworks = self.paymentNetworks
        
        updateRequest?(request)
        request.shippingMethods = updateShippingMethods?()
		request.paymentSummaryItems = self.updateSummaryItems?(request.shippingMethods?.first) ?? self.productId.items
        
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
		completion(.init(paymentSummaryItems: self.updateSummaryItems?(shippingMethod) ?? self.productId.items))
    }
}



// MARK: - Generate STPToken -

extension ApplePayService {
	fileprivate func generateSTPToken(_ payment: PKPayment, _ completion: @escaping (PKPaymentAuthorizationResult) -> Void) {		
		let toCompleteResult: (PKPaymentAuthorizationResult) -> Void = { [weak self] result in
			completion(result)
			self?.completionResult?(result)
		}
		
		let errorCompletion: (Error?) -> Void = { error in
			let failureResult = PKPaymentAuthorizationResult(status: .failure,
															 errors: error == nil ? nil : [error!])
			toCompleteResult(failureResult)
		}
		
		Stripe.setDefaultPublishableKey(Bundle.InfoPlistKeys.ApplePayment.StripePublishableTestKey.value)
		
		STPAPIClient.shared().createToken(with: payment) { [weak self] (stpTokenOptional, error) in
			self?.generatedSTPToken?(stpTokenOptional, error)
			
			guard let stripeToken = stpTokenOptional,
				error == nil else {
					errorCompletion(error)
					return
			}
			
			self?.apiService.chargeByStripeToken(stripeToken.tokenId, self?.productId.rawValue ?? String())
				.then { (isSuccees) in
					toCompleteResult(.init(status: .success, errors: nil))
			} .catch { (error) in
				errorCompletion(error)
			}
		}
	}
}
