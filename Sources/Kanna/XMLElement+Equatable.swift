//
//  XMLElement+Equatable.swift
//  
//
//  Created by Pat Nakajima on 4/28/24.
//

import Foundation

extension XMLNode: Equatable {
	public static func == (lhs: XMLNode, rhs: XMLNode) -> Bool {
		lhs.sameAs(to: rhs)
	}

	func sameAs(to element: XMLNode) -> Bool {
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
