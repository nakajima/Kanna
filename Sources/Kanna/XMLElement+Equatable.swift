//
//  XMLElement+Equatable.swift
//  
//
//  Created by Pat Nakajima on 4/28/24.
//

import Foundation

extension XMLElement: Equatable {
	public static func == (lhs: XMLElement, rhs: XMLElement) -> Bool {
		lhs.sameAs(to: rhs)
	}

	func sameAs(to element: XMLElement) -> Bool {
		if text != element.text || tagName != element.tagName || attributes != element.attributes {
			return false
		}

		if children.count != element.children.count {
			return false
		}

		for (i, child) in children.enumerated() {
			if !child.sameAs(to: element.children[i]) {
				return false
			}
		}

		return true
	}
}
