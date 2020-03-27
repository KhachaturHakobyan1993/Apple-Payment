//
//  IApplePayService.swift
//  Wiredmates
//
//  Created by Khachatur Hakobyan on 3/18/20.
//  Copyright © 2020 Wiredmates. All rights reserved.
//

import PassKit
import Stripe

internal protocol IApplePayService {
    typealias CanMakePaymentsType = ((Bool) -> Void)?
    typealias UpdateRequestType = ((PKPaymentRequest) -> Void)?
    typealias UpdateShippingMethodsType = (() -> [PKShippingMethod])?
    typealias UpdateSummaryItemsType = ((PKShippingMethod?) -> [PKPaymentSummaryItem])?
    typealias AuthorizationViewControllerHandlerType = ((PKPaymentAuthorizationViewController?) -> Void)?
    typealias AuthorizedPaymentType = ((PKPayment) -> Void)?
    typealias GeneratedSTPTokenType = ((STPToken?, Error?) -> Void)?
    typealias FinishedAuthorizationViewController = ((PKPaymentAuthorizationViewController) -> Void)?
    typealias CompletionResultType = ((PKPaymentAuthorizationResult) -> Void)?
    
	func showApplePayViewControllerIfNeeded(productId: PaymentProductIds,
											canMakePayments: CanMakePaymentsType,
                                            updateRequest: UpdateRequestType,
                                            updateShippingMethods: UpdateShippingMethodsType,
                                            updateSummaryItems: UpdateSummaryItemsType,
                                            authorizationViewControllerHandler: AuthorizationViewControllerHandlerType,
                                            authorizedPayment: AuthorizedPaymentType,
                                            generatedSTPToken: GeneratedSTPTokenType,
                                            completionResult: CompletionResultType,
                                            finishedAuthorizationViewController: FinishedAuthorizationViewController)
}
