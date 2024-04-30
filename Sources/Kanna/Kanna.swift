/** @file Kanna.swift

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

/*
 ParseOption
 */
public enum ParseOption {
	// libxml2
	case xmlParseUseLibxml(Libxml2XMLParserOptions)
	case htmlParseUseLibxml(Libxml2HTMLParserOptions)
}

public let kDefaultXmlParseOption = ParseOption.xmlParseUseLibxml([.RECOVER, .NOERROR, .NOWARNING])
public let kDefaultHtmlParseOption = ParseOption.htmlParseUseLibxml([.RECOVER, .NOERROR, .NOWARNING])

public enum ParseError: Error {
	case Empty
	case EncodingMismatch
	case InvalidOptions
}

/**
 Parse XML

 @param xml      an XML string
 @param url      the base URL to use for the document
 @param encoding the document encoding
 @param options  a ParserOption
 */
public func XML(xml: String, url: String? = nil, encoding: String.Encoding, option: ParseOption = kDefaultXmlParseOption) throws -> any XMLDocument {
	switch option {
	case let .xmlParseUseLibxml(opt):
		return try libxmlXMLDocument(xml: xml, url: url, encoding: encoding, option: opt.rawValue)
	default:
		throw ParseError.InvalidOptions
	}
}

// NSData
public func XML(xml: Data, url: String? = nil, encoding: String.Encoding, option: ParseOption = kDefaultXmlParseOption) throws -> any XMLDocument {
	guard let xmlStr = String(data: xml, encoding: encoding) else {
		throw ParseError.EncodingMismatch
	}
	return try XML(xml: xmlStr, url: url, encoding: encoding, option: option)
}

// NSURL
public func XML(url: URL, encoding: String.Encoding, option: ParseOption = kDefaultXmlParseOption) throws -> any XMLDocument {
	guard let data = try? Data(contentsOf: url) else {
		throw ParseError.EncodingMismatch
	}
	return try XML(xml: data, url: url.absoluteString, encoding: encoding, option: option)
}

/**
 Parse HTML

 @param html     an HTML string
 @param url      the base URL to use for the document
 @param encoding the document encoding
 @param options  a ParserOption
 */
public func HTML(html: String, url: String? = nil, encoding: String.Encoding, option: ParseOption = kDefaultHtmlParseOption) throws -> HTMLDocument {
	switch option {
	case let .htmlParseUseLibxml(opt):
		return try HTMLDocument(html: html, url: url, encoding: encoding, option: opt.rawValue)
	default:
		throw ParseError.InvalidOptions
	}
}

// NSData
public func HTML(html: Data, url: String? = nil, encoding: String.Encoding, option: ParseOption = kDefaultHtmlParseOption) throws -> HTMLDocument {
	guard let htmlStr = String(data: html, encoding: encoding) else {
		throw ParseError.EncodingMismatch
	}
	return try HTML(html: htmlStr, url: url, encoding: encoding, option: option)
}

// NSURL
public func HTML(url: URL, encoding: String.Encoding, option: ParseOption = kDefaultHtmlParseOption) throws -> HTMLDocument {
	guard let data = try? Data(contentsOf: url) else {
		throw ParseError.EncodingMismatch
	}
	return try HTML(html: data, url: url.absoluteString, encoding: encoding, option: option)
}

/**
 Searchable
 */
public protocol Searchable {
	/**
	 Search for node from current node by XPath.

	 @param xpath
	  */
	func xpath(_ xpath: String, namespaces: [String: String]?) -> XPathObject

	/**
	 Search for node from current node by CSS selector.

	 @param selector a CSS selector
	 */
	func css(_ selector: String, namespaces: [String: String]?) -> XPathObject
}

public extension Searchable {
	func xpath(_ xpath: String, namespaces: [String: String]? = nil) -> XPathObject {
		self.xpath(xpath, namespaces: namespaces)
	}

	func at_xpath(_ xpath: String, namespaces: [String: String]? = nil) -> XMLNode? {
		self.xpath(xpath, namespaces: namespaces).nodeSetValue.first
	}

	func css(_ selector: String, namespaces: [String: String]? = nil) -> XPathObject {
		css(selector, namespaces: namespaces)
	}

	func at_css(_ selector: String, namespaces: [String: String]? = nil) -> XMLNode? {
		css(selector, namespaces: namespaces).nodeSetValue.first
	}
}

/**
 SearchableNode
 */
public protocol SearchableNode: Searchable {
	var text: String? { get }
	var toHTML: String? { get }
	var toXML: String? { get }
	var innerHTML: String? { get }
	var className: String? { get }
	var tagName: String? { get set }
	var content: String? { get set }
}

/**
 XMLElement
 */
public protocol XMLElementProtocol: AnyObject, SearchableNode {
	var parent: XMLNode? { get set }
	var attributes: [String: String?] { get }
	var children: [XMLNode] { get }
	subscript(_: String) -> String? { get set }

	func addPrevSibling(_ node: XMLNode)
	func addNextSibling(_ node: XMLNode)
	func removeChild(_ node: XMLNode)
	func replace(with: XMLNode)
	func addChild(_ node: XMLNode)
	var nextElementSibling: XMLNode? { get }
	var previousElementSibling: XMLNode? { get }
	var nextSibling: XMLNode? { get }
	var previousSibling: XMLNode? { get }
}

/**
 XMLDocument
 */
public protocol XMLDocument: AnyObject, SearchableNode {
	var namespaces: [Namespace] { get }
}

public extension XMLDocument {
	var namespaceDictionary: [String: String]? {
		let dictionary = namespaces.reduce(into: [:]) {
			// when prefix is blank, treat prefix "" as "xmlns", or xpath cannot specify "" as prefix
			$0[$1.prefix == "" ? "xmlns" : $1.prefix] = $1.name
		}
		return dictionary.count > 0 ? dictionary : nil
	}
}

/**
 HTMLDocument
 */
public protocol HTMLDocumentProtocol: XMLDocument {
	var title: String? { get }
	var head: XMLNode? { get }
	var body: XMLNode? { get }
	func create(node: String, content: String?) -> XMLNode?
}

/**
 XMLNodeSet
 */
public final class XMLNodeSet {
	private var nodes: [XMLNode]

	public var toHTML: String? {
		let html = nodes.reduce("") {
			if let text = $1.toHTML {
				return $0 + text
			}
			return $0
		}
		return html.isEmpty == false ? html : nil
	}

	public var innerHTML: String? {
		let html = nodes.reduce("") {
			if let text = $1.innerHTML {
				return $0 + text
			}
			return $0
		}
		return html.isEmpty == false ? html : nil
	}

	public var text: String? {
		let html = nodes.reduce("") {
			if let text = $1.text {
				return $0 + text
			}
			return $0
		}
		return html
	}

	public subscript(index: Int) -> XMLNode {
		nodes[index]
	}

	public var count: Int { nodes.count }

	init(nodes: [XMLNode] = []) {
		self.nodes = nodes
	}

	public func at(_ index: Int) -> XMLNode? {
		count > index ? nodes[index] : nil
	}

	public var first: XMLNode? { at(0) }
	public var last: XMLNode? { at(count - 1) }
}

extension XMLNodeSet: Sequence {
	public typealias Iterator = AnyIterator<XMLNode>
	public func makeIterator() -> Iterator {
		var index = 0
		return AnyIterator {
			if index < self.nodes.count {
				let n = self.nodes[index]
				index += 1
				return n
			}
			return nil
		}
	}
}

/**
 Namespace
 */
public struct Namespace {
	public let prefix: String
	public let name: String
}

/**
 XPathObject
 */
public enum XPathObject {
	case none
	case NodeSet(nodeset: XMLNodeSet)
	case Bool(bool: Swift.Bool)
	case Number(num: Double)
	case String(text: Swift.String)
}

extension XPathObject {
	init(document: (any XMLDocument)?, docPtr: xmlDocPtr, object: xmlXPathObject) {
		switch object.type {
		case XPATH_NODESET:
			guard let nodeSet = object.nodesetval, nodeSet.pointee.nodeNr != 0, let nodeTab = nodeSet.pointee.nodeTab else {
				self = .none
				return
			}

			var nodes: [XMLNode] = []
			let size = Int(nodeSet.pointee.nodeNr)
			for i in 0 ..< size {
				let node: xmlNodePtr = nodeTab[i]!
				let htmlNode = XMLNode(document: document, docPtr: docPtr, node: node)
				nodes.append(htmlNode)
			}
			self = .NodeSet(nodeset: XMLNodeSet(nodes: nodes))
			return
		case XPATH_BOOLEAN:
			self = .Bool(bool: object.boolval != 0)
			return
		case XPATH_NUMBER:
			self = .Number(num: object.floatval)
		case XPATH_STRING:
			guard let str = UnsafeRawPointer(object.stringval)?.assumingMemoryBound(to: CChar.self) else {
				self = .String(text: "")
				return
			}
			self = .String(text: Swift.String(cString: str))
			return
		default:
			self = .none
			return
		}
	}

	public subscript(index: Int) -> XMLNode {
		nodeSet![index]
	}

	public var first: XMLNode? {
		nodeSet?.first
	}

	public var count: Int {
		nodeSet?.count ?? 0
	}

	var nodeSet: XMLNodeSet? {
		if case let .NodeSet(nodeset) = self {
			return nodeset
		}
		return nil
	}

	var bool: Swift.Bool? {
		if case let .Bool(value) = self {
			return value
		}
		return nil
	}

	var number: Double? {
		if case let .Number(value) = self {
			return value
		}
		return nil
	}

	var string: Swift.String? {
		if case let .String(value) = self {
			return value
		}
		return nil
	}

	var nodeSetValue: XMLNodeSet {
		nodeSet ?? XMLNodeSet()
	}

	var boolValue: Swift.Bool {
		bool ?? false
	}

	var numberValue: Double {
		number ?? 0
	}

	var stringValue: Swift.String {
		string ?? ""
	}
}

extension XPathObject: Sequence {
	public typealias Iterator = AnyIterator<XMLNode>
	public func makeIterator() -> Iterator {
		var index = 0
		return AnyIterator {
			if index < self.nodeSetValue.count {
				let obj = self.nodeSetValue[index]
				index += 1
				return obj
			}
			return nil
		}
	}
}
