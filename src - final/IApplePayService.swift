//
//  IApplePayService.swift
//  Swift Academy
//
//  Created by Khachatur Hakobyan on 3/18/20.
//  Copyright © 2020 Swift Academy. All rights reserved.
//

import PassKit
import Stripe

internal protocol IApplePayService {
    typealias CanMakePaymentsHandlerType = ((Bool) -> Void)?
    typealias UpdateRequestType = ((PKPaymentRequest) -> Void)?
    typealias UpdateShippingMethodsType = (() -> [PKShippingMethod])?
    typealias UpdateSummaryItemsType = ((PKShippingMethod?) -> [PKPaymentSummaryItem])?
    typealias AuthorizationViewControllerHandlerType = ((PKPaymentAuthorizationViewController?) -> Void)?
    typealias AuthorizedPaymentType = ((PKPayment) -> Void)?
    typealias GeneratedSTPPaymentMethodType = ((STPPaymentMethod?, Error?) -> Void)?
    typealias FinishedAuthorizationViewController = ((PKPaymentAuthorizationViewController) -> Void)?
    typealias CompletionResultType = ((PKPaymentAuthorizationResult) -> Void)?
    
	func showApplePayViewControllerIfNeeded(productId: PaymentProductIds,
											canMakePaymentsHandler: CanMakePaymentsHandlerType,
                                            updateRequest: UpdateRequestType,
                                            updateShippingMethods: UpdateShippingMethodsType,
                                            updateSummaryItems: UpdateSummaryItemsType,
                                            authorizationViewControllerHandler: AuthorizationViewControllerHandlerType,
                                            authorizedPayment: AuthorizedPaymentType,
                                            generatedSTPPaymentMethod: GeneratedSTPPaymentMethodType,
                                            completionResult: CompletionResultType,
                                            finishedAuthorizationViewController: FinishedAuthorizationViewController)
}
