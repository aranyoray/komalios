//
//  Extension.swift
//  Komalios
//
//  Created by Amit Kumar on 19/01/26.
//

import UIKit

extension UIApplication {
    func hideKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder),
                   to: nil, from: nil, for: nil)
    }
}
