//
//  KannaTutorialsTest.swift
//  Kanna
//
//  Created by Atsushi Kiwaki on 6/27/16.
//  Copyright © 2016 tid. All rights reserved.
//
import CoreFoundation
import Foundation
import Kanna
import XCTest

class KannaTutorialsTests: XCTestCase {
	func testParsingFromString() {
		let html = "<html><body><h1>Tutorials</h1></body></html>"
		if let htmlDoc = try? HTML(html: html, encoding: .utf8) {
			XCTAssert(htmlDoc.toHTML != nil)
		}

		let xml = "<root><item><name>Tutorials</name></item></root>"
		if let xmlDoc = try? XML(xml: xml, encoding: .utf8) {
			XCTAssert(xmlDoc.toXML != nil)
		}
	}

	func testParsingFromFile() {
		let filename = "test_HTML4"
		guard let filePath = Bundle.testBundle(for: KannaTutorialsTests.self).path(forResource: filename, ofType: "html") else {
			XCTFail()
			return
		}
		if let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
		   let doc = try? HTML(html: data, encoding: .utf8)
		{
			XCTAssert(doc.toHTML != nil)
		}

		if let html = try? String(contentsOfFile: filePath, encoding: .utf8),
		   let doc = try? HTML(html: html, encoding: .utf8)
		{
			XCTAssert(doc.toHTML != nil)
		}
	}

	func testParsingFromInternets() {
		let url = URL(string: "https://en.wikipedia.org/wiki/Cat")
		if let doc = try? HTML(url: url!, encoding: .utf8) {
			XCTAssert(doc.toHTML != nil)
		}
	}

	func testParsingFromEncoding() {
		let html = "<html><body><h1>Tutorials</h1></body></html>"
		if let htmlDoc = try? HTML(html: html, encoding: .japaneseEUC) {
			XCTAssert(htmlDoc.toHTML != nil)
		}
	}

	func testParsingOptions() {
		let html = "<html><body><h1>Tutorials</h1></body></html>"
		if let doc = try? HTML(html: html, encoding: .utf8, option: .htmlParseUseLibxml([.STRICT])) {
			XCTAssert(doc.toHTML != nil)
		}
	}

	func testSearchingBasicSearching() {
		let testVersionData = [
			"iOS 10",
			"iOS 9",
			"iOS 8",
			"macOS 10.12",
			"macOS 10.11",
			"tvOS 10.0",
		]

		let testVersionDataIOS = [
			"iOS 10",
			"iOS 9",
			"iOS 8",
		]
		let filename = "versions"
		guard let filePath = Bundle.testBundle(for: KannaTutorialsTests.self).path(forResource: filename, ofType: "xml") else {
			XCTFail()
			return
		}
		if let xml = try? String(contentsOfFile: filePath, encoding: .utf8),
		   let doc = try? XML(xml: xml, encoding: .utf8)
		{
			for (i, node) in doc.xpath("//name").enumerated() {
				XCTAssert(node.text! == testVersionData[i])
			}

			let nodes = doc.xpath("//name")
			XCTAssert(nodes[0].text! == testVersionData[0])

			for (i, node) in doc.xpath("//ios//name").enumerated() {
				XCTAssert(node.text! == testVersionDataIOS[i])
			}

			for (i, node) in doc.css("ios name").enumerated() {
				XCTAssert(node.text! == testVersionDataIOS[i])
			}

			XCTAssert(doc.css("tvos name").first!.text == "tvOS 10.0")
			XCTAssert(doc.at_css("tvos name")!.text == "tvOS 10.0")
		}
	}

	func testSearchingNamespaces() {
		let testLibrariesDataGitHub = [
			"Kanna",
			"Alamofire",
		]

		let testLibrariesDataBitbucket = [
			"Hoge",
		]

		let filename = "libraries"
		guard let filePath = Bundle.testBundle(for: KannaTutorialsTests.self).path(forResource: filename, ofType: "xml"),
		      let xml = try? String(contentsOfFile: filePath, encoding: .utf8)
		else {
			XCTFail()
			return
		}

		if let doc = try? XML(xml: xml, encoding: .utf8) {
			for (i, node) in doc.xpath("//github:title", namespaces: ["github": "https://github.com/"]).enumerated() {
				XCTAssert(node.text! == testLibrariesDataGitHub[i])
			}
		}

		if let doc = try? XML(xml: xml, encoding: .utf8) {
			for (i, node) in doc.xpath("//bitbucket:title", namespaces: ["bitbucket": "https://bitbucket.org/"]).enumerated() {
				XCTAssert(node.text! == testLibrariesDataBitbucket[i])
			}
		}
	}

	func testModifyingChangingTextContents() {
		let TestModifyHTML = "<body>\n    <h1>Snap, Crackle &amp; Pop</h1>\n    <div>A love triangle.</div>\n</body>"
		let filename = "sample"
		guard let filePath = Bundle.testBundle(for: KannaTutorialsTests.self).path(forResource: filename, ofType: "html"),
		      let html = try? String(contentsOfFile: filePath, encoding: .utf8)
		else {
			XCTFail()
			return
		}

		guard let doc = try? HTML(html: html, encoding: .utf8) else {
			return
		}

		var h1 = doc.at_css("h1")!
		h1.content = "Snap, Crackle & Pop"

		XCTAssert(doc.body?.toHTML == TestModifyHTML)
	}

	func testModifyingMovingNode() {
		let TestModifyHTML = "<body>\n    \n    <div>A love triangle.<h1>Three\'s Company</h1>\n</div>\n</body>"
		let TestModifyArrangeHTML = "<body>\n    \n    <div>A love triangle.</div>\n<h1>Three\'s Company</h1>\n</body>"
		let filename = "sample"
		guard let filePath = Bundle.testBundle(for: KannaTutorialsTests.self).path(forResource: filename, ofType: "html"),
		      let html = try? String(contentsOfFile: filePath, encoding: .utf8)
		else {
			XCTFail()
			return
		}

		guard let doc = try? HTML(html: html, encoding: .utf8) else {
			return
		}
		var h1 = doc.at_css("h1")!
		let div = doc.at_css("div")!

		h1.parent = div

		XCTAssert(doc.body!.toHTML == TestModifyHTML)

		div.addNextSibling(h1)

		XCTAssert(doc.body!.toHTML == TestModifyArrangeHTML)
	}

	func testModifyingNodesAndAttributes() {
		let TestModifyHTML = "<body>\n    <h2 class=\"show-title\">Three\'s Company</h2>\n    <div>A love triangle.</div>\n</body>"
		let filename = "sample"
		guard let filePath = Bundle.testBundle(for: KannaTutorialsTests.self).path(forResource: filename, ofType: "html"),
		      let html = try? String(contentsOfFile: filePath, encoding: .utf8)
		else {
			XCTFail()
			return
		}

		guard let doc = try? HTML(html: html, encoding: .utf8) else {
			return
		}
		var h1 = doc.at_css("h1")!

		h1.tagName = "h2"
		h1["class"] = "show-title"

		XCTAssert(doc.body?.toHTML == TestModifyHTML)
	}

	func testListAttributes() throws {
		let html = """
		<body>
			<h2 class="show-title" data-hello="world">Three's Company</h2>
		</body>
		"""

		let document = try HTML(html: html, encoding: .utf8)
		let h2 = document.at_css("h2")!
		XCTAssertEqual(["class": "show-title", "data-hello": "world"], h2.attributes)
	}

	func testReplaceElement() throws {
		let html = """
		<body>
			<h2 class="show-title" data-hello="world">Three's Company</h2>
		</body>
		"""

		let document = try HTML(html: html, encoding: .utf8)
		let h2 = document.at_css("h2")!

		let replacement = document.create(node: "p", content: "replaced!")!
		h2.replace(with: replacement)

		XCTAssertEqual(0, document.css("h2").count)

		// Make sure it's swapped in the doc
		let p = try XCTUnwrap(document.at_css("p"))
		XCTAssertEqual("replaced!", p.text)

		// Make sure the element itself is swapped
		XCTAssertEqual("p", h2.tagName)
	}

	func testAddChild() throws {
		let html = """
		<body>
			<div><p>Hello</p></div>
		</body>
		"""

		let document = try HTML(html: html, encoding: .utf8)
		let div = document.at_css("div")!

		let p = try XCTUnwrap(
			document.create(node: "p", content: "added!")
		)

		div.addChild(p)

		XCTAssertEqual(2, div.css("p").count)
		XCTAssertEqual("added!", Array(div.css("p")).last?.text)
	}

	func testChildren() throws {
		let html = """
		<body>
			<div>hello <p>world</p></div>
		</body>
		"""

		let document = try HTML(html: html, encoding: .utf8)
		let div = document.at_css("div")!

		XCTAssertEqual(2, div.children.count)
		XCTAssertEqual("hello ", div.children[0].text)
		XCTAssertEqual("world", div.children[1].text)
	}

	func testEquality() throws {
		let first = try HTML(html: "<div><p>Hello</p><p><strong>World</strong></p>", encoding: .utf8).body
		let second = try HTML(html: "<div><p>Hello</p><p><strong>World</strong></p>", encoding: .utf8).body
		let third = try HTML(html: "<div><p>Hello</p><p><strong class='foo'>World</strong></p>", encoding: .utf8).body

		XCTAssertEqual(first, second)
		XCTAssertNotEqual(second, third)
	}

	func testTraverseUp() throws {
		let document = try HTML(html: """
		<div>
			<p>
				<strong>
					Hi
				</strong>
			</p>
		</div>
		""", encoding: .utf8)

		var node = document.at_css("strong")!
		var i = 0
		while let parent = node.parent {
			i += 1
			node = parent
		}

		XCTAssertEqual(5, i) // strong -> p -> div -> body -> html
	}

	func testSetInnerHTML() throws {
		let document = try HTML(html: """
		<div>
			<p>
				<strong>
					Hi
				</strong>
			</p>
		</div>
		""", encoding: .utf8)

		document.body!.innerHTML = "<p>different</p>"

		XCTAssertEqual(document.body!.toHTML, "<body><p>different</p></body>")
	}
}

extension KannaTutorialsTests {
	static var allTests: [(String, (KannaTutorialsTests) -> () throws -> Void)] {
		[
			("testParsingFromString", testParsingFromString),
			// ("testParsingFromFile", testParsingFromFile),
			("testParsingFromInternets", testParsingFromInternets),
			("testParsingFromEncoding", testParsingFromEncoding),
			("testParsingOptions", testParsingOptions),
			// ("testSearchingBasicSearching", testSearchingBasicSearching),
			// ("testSearchingNamespaces", testSearchingNamespaces),
			// ("testModifyingChangingTextContents", testModifyingChangingTextContents),
			// ("testModifyingMovingNode", testModifyingMovingNode),
			// ("testModifyingNodesAndAttributes", testModifyingNodesAndAttributes)
		]
	}
}
