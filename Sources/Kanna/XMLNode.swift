/** @file libxmlHTMLNode.swift

 Kanna

 Copyright (c) 2015 Atsushi Kiwaki (@_tid_)

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */
import Foundation
import libxml2

/**
 libxmlHTMLNode
 */
public final class XMLNode: Searchable {
	public init(document: (any XMLDocument)?, docPtr: xmlDocPtr) throws {
		self.weakDocument = document
		self.docPtr = docPtr
		guard let nodePtr = xmlDocGetRootElement(docPtr) else {
			// Error handling is omitted, and will be added if necessary in the future.
			// e.g: if let error = xmlGetLastError(), error.pointee.code == XML_ERR_DOCUMENT_EMPTY.rawValue
			throw ParseError.Empty
		}
		self.nodePtr = nodePtr
	}

	public init(document: (any XMLDocument)?, docPtr: xmlDocPtr, node: xmlNodePtr) {
		self.document = document
		self.docPtr = docPtr
		self.nodePtr = node
	}

	deinit {
		if let nodePtr {
			xmlFreeNode(nodePtr)
		}
	}

	public var text: String? {
		guard let nodePtr else { return nil}

		return libxmlGetNodeContent(nodePtr)
	}

	public var toHTML: String? {
		let buf = xmlBufferCreate()
		htmlNodeDump(buf, docPtr, nodePtr)
		let html = String(cString: UnsafePointer<UInt8>((buf?.pointee.content)!))
		xmlBufferFree(buf)
		return html
	}

	public var toXML: String? {
		let buf = xmlBufferCreate()
		xmlNodeDump(buf, docPtr, nodePtr, 0, 0)
		let html = String(cString: UnsafePointer<UInt8>((buf?.pointee.content)!))
		xmlBufferFree(buf)
		return html
	}

	public var innerHTML: String? {
		get {
			guard let html = toHTML else { return nil }
			return html
				.replacingOccurrences(of: "</[^>]*>$", with: "", options: .regularExpression, range: nil)
				.replacingOccurrences(of: "^<[^>]*>", with: "", options: .regularExpression, range: nil)
		}

		set {
			guard let newValue else { return }

			let option: Libxml2XMLParserOptions = [.RECOVER, .NOERROR, .NOWARNING]
			let cur = newValue.cString(using: .utf8)!

			let fragment = cur.withUnsafeBytes {
				let pointer = $0.bindMemory(to: xmlChar.self)
				return xmlReadMemory(pointer.baseAddress, Int32(pointer.count), nil, nil, Int32(option.rawValue))
			}

			var newChildren: [xmlNodePtr] = []
			var child = fragment?.pointee.children
			while let childPtr = child {
				newChildren.append(childPtr)
				child = childPtr.pointee.next
			}

			for child in children {
				removeChild(child)
			}

			for newChildPtr in newChildren {
				if let node = node(from: newChildPtr) {
					addChild(node)
				}
			}
		}
	}

	public var className: String? {
		self["class"]
	}

	public var tagName: String? {
		get {
			guard let nodePtr else { return nil}

			guard let name = nodePtr.pointee.name else {
				return nil
			}
			return String(cString: name)
		}
		set {
			if let newValue = newValue {
				xmlNodeSetName(nodePtr, newValue)
			}
		}
	}

	public var content: String? {
		get { text }
		set {
			if let newValue = newValue {
				let v = escape(newValue)
				xmlNodeSetContent(nodePtr, v)
			}
		}
	}

	public var parent: XMLNode? {
		get {
			guard let nodePtr else { return nil}

			let parent = withUnsafeMutablePointer(to: &nodePtr.pointee) {
				$0.pointee.parent
			}

			guard let parent else {
				return nil
			}

			return XMLNode(document: doc, docPtr: docPtr, node: UnsafeMutablePointer(parent))
		}
		set {
			if let node = newValue {
				node.addChild(self)
			}
		}
	}

	public var firstElementChild: XMLNode? {
		guard let nodePtr else { return nil}
		return node(from: xmlFirstElementChild(nodePtr))
	}

	public var firstChild: XMLNode? {
		guard let nodePtr else { return nil}
		return node(from: nodePtr.pointee.children)
	}

	public var lastChild: XMLNode? {
		guard let nodePtr else { return nil}
		return node(from: nodePtr.pointee.last)
	}

	public var lastElementChild: XMLNode? {
		guard let nodePtr else { return nil}
		return node(from: xmlLastElementChild(nodePtr))
	}

	public var nextElementSibling: XMLNode? {
		guard let nodePtr else { return nil}
		return node(from: xmlNextElementSibling(nodePtr))
	}

	public var previousElementSibling: XMLNode? {
		guard let nodePtr else { return nil}
		return node(from: xmlPreviousElementSibling(nodePtr))
	}

	public var nextSibling: XMLNode? {
		guard let nodePtr else { return nil}
		return node(from: nodePtr.pointee.next)
	}

	public var previousSibling: XMLNode? {
		guard let nodePtr else { return nil}
		return node(from: nodePtr.pointee.prev)
	}

	public var children: [XMLNode] {
		var result: [XMLNode] = []
		guard let nodePtr else { return [] }

		if var child = nodePtr.pointee.children {
			if let childNode = node(from: child) {
				result.append(childNode)
			}

			if child.pointee.next == nil {
				return result
			}

			while let nextChildPtr = child.pointee.next {
				if let nextChild = node(from: nextChildPtr) {
					result.append(nextChild)
					child = nextChildPtr
				}
			}

			return result
		} else {
			return []
		}
	}

	private weak var weakDocument: (any XMLDocument)?
	private var document: (any XMLDocument)?
	private var docPtr: htmlDocPtr
	private var nodePtr: xmlNodePtr?
	private var doc: (any XMLDocument)? {
		weakDocument ?? document
	}

	public subscript(attributeName: String) -> String? {
		get {
			guard let nodePtr else { return nil}

			var attr = nodePtr.pointee.properties
			while attr != nil {
				let mem = attr!.pointee
				let prefix = mem.ns.flatMap { $0.pointee.prefix.string }
				let tagName = [prefix, mem.name.string].compactMap { $0 }.joined(separator: ":")
				if attributeName == tagName {
					if let children = mem.children {
						return libxmlGetNodeContent(children)
					} else {
						return ""
					}
				}
				attr = attr!.pointee.next
			}
			return nil
		}
		set(newValue) {
			if let newValue = newValue {
				xmlSetProp(nodePtr, attributeName, newValue)
			} else {
				xmlUnsetProp(nodePtr, attributeName)
			}
		}
	}

	public var attributes: [String: String?] {
		var result: [String: String?] = [:]

		guard let nodePtr else { return [:] }

		var attribute = nodePtr.pointee.properties

		while let attr = attribute {
			let mem = attr.pointee
			let prefix = mem.ns.flatMap { $0.pointee.prefix.string }
			let attributeName = [prefix, mem.name.string].compactMap { $0 }.joined(separator: ":")

			if let children = mem.children {
				result[attributeName] = libxmlGetNodeContent(children)
			}

			attribute = attr.pointee.next
		}

		return result
	}

	// MARK: Searchable

	public func xpath(_ xpath: String, namespaces: [String: String]? = nil) -> XPathObject {
		guard let doc = doc else { return .none }
		return XPath(doc: doc, docPtr: docPtr, nodePtr: nodePtr).xpath(xpath, namespaces: namespaces)
	}

	public func css(_ selector: String, namespaces: [String: String]? = nil) -> XPathObject {
		guard let doc = doc else { return .none }
		return XPath(doc: doc, docPtr: docPtr, nodePtr: nodePtr).css(selector, namespaces: namespaces)
	}

	public func addPrevSibling(_ node: XMLNode) {
		xmlAddPrevSibling(nodePtr, node.nodePtr)
	}

	public func addNextSibling(_ node: XMLNode) {
		xmlAddNextSibling(nodePtr, node.nodePtr)
	}

	public func addChild(_ node: XMLNode) {
		xmlUnlinkNode(node.nodePtr)
		xmlAddChild(nodePtr, node.nodePtr)
	}

	public func removeChild(_ node: XMLNode) {
		xmlUnlinkNode(node.nodePtr)
	}

	public func remove() {
		xmlUnlinkNode(nodePtr)
	}

	public func replace(with node: XMLNode) {
		xmlReplaceNode(nodePtr, node.nodePtr)
		nodePtr = node.nodePtr
	}

	public func recursiveCopy() -> XMLNode? {
		guard let newNode = node(from: xmlNewNode(nil, tagName)) else {
			return nil
		}

		for (name, value) in attributes {
			newNode[name] = value
		}

		for child in children {
			if child.tagName == "text",
				 let textNodePtr = xmlNewText(child.text),
				 let textNode = node(from: textNodePtr) {
				newNode.addChild(textNode)
			} else {
				if let childCopy = child.recursiveCopy() {
					newNode.addChild(childCopy)
				} else {
					return nil
				}
			}
		}

		return newNode
	}

	private func node(from ptr: xmlNodePtr?) -> XMLNode? {
		guard let doc = doc, let nodePtr = ptr else {
			return nil
		}

		return XMLNode(document: doc, docPtr: docPtr, node: nodePtr)
	}
}

private func libxmlGetNodeContent(_ nodePtr: xmlNodePtr) -> String? {
	guard let content = xmlNodeGetContent(nodePtr) else {
		return nil
	}
	defer {
		#if swift(>=4.1)
			content.deallocate()
		#else
			content.deallocate(capacity: 1)
		#endif
	}
	if let result = String(validatingUTF8: UnsafeRawPointer(content).assumingMemoryBound(to: CChar.self)) {
		return result
	}
	return nil
}

let entities = [
	("&", "&amp;"),
	("<", "&lt;"),
	(">", "&gt;"),
]

private func escape(_ str: String) -> String {
	var newStr = str
	for (unesc, esc) in entities {
		newStr = newStr.replacingOccurrences(of: unesc, with: esc, options: .regularExpression, range: nil)
	}
	return newStr
}

private extension UnsafePointer<UInt8> {
	var string: String? {
		let string = String(validatingUTF8: UnsafePointer<CChar>(OpaquePointer(self)))
		return string
	}
}
