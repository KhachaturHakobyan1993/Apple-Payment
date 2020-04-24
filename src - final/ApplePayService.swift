//
//  ApplePayService.swift
//  Swift Academy
//
//  Created by Khachatur Hakobyan on 3/16/20.
//  Copyright © 2020 Swift Academy. All rights reserved.
//

import Foundation
import PassKit
import Stripe

internal final class ApplePayService: NSObject, IApplePayService {
    private let apiService: IApiService
    private let dialogService: IDialogService
    private let paymentNetworks = [PKPaymentNetwork.visa, .amex, .masterCard, .discover]
    private var canMakePayments: Bool { return PKPaymentAuthorizationController.canMakePayments(usingNetworks: self.paymentNetworks) }
    private var productId: PaymentProductIds!
    private var canMakePaymentsHandler: CanMakePaymentsHandlerType!
    private var updateRequest: UpdateRequestType!
    private var updateShippingMethods: UpdateShippingMethodsType!
    private var updateSummaryItems: UpdateSummaryItemsType = nil
    private var authorizationViewControllerHandler: AuthorizationViewControllerHandlerType!
    private var authorizedPayment: AuthorizedPaymentType = nil
    private var generatedSTPPaymentMethod: GeneratedSTPPaymentMethodType = nil
    private var completionResult: CompletionResultType = nil
    private var finishedAuthorizationViewController: FinishedAuthorizationViewController = nil
    
    private enum DisplayMessageType {
        case userCanNotMakePayments
        case chargeByPaymentMethodInvalid(error: Error)
    }
    
    
    init(_ apiService: IApiService,
         _ dialogService: IDialogService) {
        self.apiService = apiService
        self.dialogService = dialogService
    }
    
    func showApplePayViewControllerIfNeeded(productId: PaymentProductIds,
                                            canMakePaymentsHandler: CanMakePaymentsHandlerType = nil,
                                            updateRequest: UpdateRequestType = nil,
                                            updateShippingMethods: UpdateShippingMethodsType = nil,
                                            updateSummaryItems: UpdateSummaryItemsType = nil,
                                            authorizationViewControllerHandler: AuthorizationViewControllerHandlerType = nil,
                                            authorizedPayment: AuthorizedPaymentType = nil,
                                            generatedSTPPaymentMethod: GeneratedSTPPaymentMethodType = nil,
                                            completionResult: CompletionResultType = nil,
                                            finishedAuthorizationViewController: FinishedAuthorizationViewController = nil) {
        self.canMakePaymentsHandler = canMakePaymentsHandler
        self.productId = productId
        self.updateRequest = updateRequest
        self.updateShippingMethods = updateShippingMethods
        self.updateSummaryItems = updateSummaryItems
        self.authorizationViewControllerHandler = authorizationViewControllerHandler
        self.authorizedPayment = authorizedPayment
        self.generatedSTPPaymentMethod = generatedSTPPaymentMethod
        self.completionResult = completionResult
        self.finishedAuthorizationViewController = finishedAuthorizationViewController
        
        self.showApplePayViewControllerIfNeededWithoutHandlers()
    }
    
    private func showApplePayViewControllerIfNeededWithoutHandlers() {
        self.canMakePaymentsHandler?(self.canMakePayments)
        
        guard self.canMakePayments else {
            self.displayErrorMessage(.userCanNotMakePayments)
            return
        }
        
        let request = PKPaymentRequest()
        request.currencyCode = Bundle.InfoPlistKeys.ApplePayment.ApplePayCurrencyCode.value
        request.countryCode = Bundle.InfoPlistKeys.ApplePayment.ApplePayCountryCode.value
        request.supportedCountries = Bundle.InfoPlistKeys.ApplePayment.ApplePaySupportedCountries.supportedCountriesValue
        request.merchantIdentifier = Bundle.InfoPlistKeys.ApplePayment.ApplePayMerchantIdentifier.value
        request.merchantCapabilities = PKMerchantCapability.capability3DS
        request.requiredShippingContactFields = .init(arrayLiteral: .name)
        request.supportedNetworks = self.paymentNetworks
        
        self.updateRequest?(request)
        request.shippingMethods = self.updateShippingMethods?()
        request.paymentSummaryItems = self.updateSummaryItems?(request.shippingMethods?.first) ?? self.productId.items
        
        let pkPaymentAuthorizationViewController = PKPaymentAuthorizationViewController(paymentRequest: request)
        pkPaymentAuthorizationViewController?.delegate = self
        
        self.authorizationViewControllerHandler?(pkPaymentAuthorizationViewController)
    }
    
    private func displayErrorMessage( _ displayMessageType: DisplayMessageType) {
        switch displayMessageType {
        case .userCanNotMakePayments:
            guard PKPassLibrary.isPassLibraryAvailable() else {
                self.dialogService.displayAlert(title: paymentErrorTitle,
                                                message: userCanNotMakePaymentsMessage,
                                                cancelButton: okTitle)
                return
            }
            
            self.dialogService.displayConfirmationAlert(title: paymentErrorTitle,
                                                        message: userCanNotMakePaymentsMessage,
                                                        cancelButton: (okTitle, .cancel),
                                                        okButton: (openWallet, .default))
                .then({ (openWallet) in
                    guard openWallet else { return }
                    
                    PKPassLibrary().openPaymentSetup()
                })
        case let .chargeByPaymentMethodInvalid(error):
            self.dialogService.displayConfirmationAlert(title: paymentErrorTitle,
                                                        message: (error.asCoreError?.description ?? paymentErrorMessage),
                                                        cancelButton: (okTitle, .cancel),
                                                        okButton: (tryAgainTitle, .default))
                .then({ [weak self] (isTryAgain) in
                    guard isTryAgain else { return }
                    
                    self?.showApplePayViewControllerIfNeededWithoutHandlers()
                })
        }
    }
}


// MARK: - PKPaymentAuthorizationViewControllerDelegate -

extension ApplePayService: PKPaymentAuthorizationViewControllerDelegate {
    internal func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController,
                                                     didAuthorizePayment payment: PKPayment,
                                                     handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        self.authorizedPayment?(payment)
        
        self.generateSTPPaymentMethod(payment, completion)
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


// MARK: - Generate STPPaymentMethod -

extension ApplePayService {
    fileprivate func generateSTPPaymentMethod(_ payment: PKPayment, _ completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
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
        
        STPAPIClient.shared().createPaymentMethod(with: payment) {  [weak self] (stpPaymentMethodOptional, error) in
            self?.generatedSTPPaymentMethod?(stpPaymentMethodOptional, error)
            
            guard let stripePaymentMethod = stpPaymentMethodOptional,
                error == nil else {
                    errorCompletion(error)
                    return
            }
            
            self?.apiService.chargeByPaymentMethod(stripePaymentMethod.stripeId, self?.productId.rawValue ?? String())
                .then { (isSuccees) in
                    toCompleteResult(.init(status: .success, errors: nil))
            } .catch { [weak self] (error) in
                errorCompletion(error)
                self?.displayErrorMessage(.chargeByPaymentMethodInvalid(error: error))
            }
        }
    }
}
