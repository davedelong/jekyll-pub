//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/14/20.
//

import Foundation

class XMLRPCDecoder {
    init() { }
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> XMLRPCMethodCall<T> {
        let doc = try XMLDocument(data: data, options: [])
        guard let name = (try doc.nodes(forXPath: "//methodCall/methodName")).first?.stringValue else {
            throw DecodingError.missingChildNode(doc.rootElement()!, "methodName", [])
        }
        
        let parameterNodes = try doc.nodes(forXPath: "//methodCall/params/param/value")
        parameterNodes.forEach { $0.detach() }
        let array = XMLElement(name: "array", child: XMLElement(name: "data", children: parameterNodes))
        let decoder = _XMLRPCDecoder(node: array, path: [])
        let parameters = try T.init(from: decoder)
        return XMLRPCMethodCall(methodName: name, parameters: parameters)
    }
}

private struct _XMLRPCDecoder: Decoder {
    var codingPath: [CodingKey]
    
    var userInfo: [CodingUserInfoKey : Any]
    
    private let node: XMLNode
    
    init(node: XMLNode, path: [CodingKey]) {
        self.node = node
        self.codingPath = path
        self.userInfo = [:]
    }
    
    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        // this should only work if the current node is "struct"
        return try KeyedDecodingContainer(_XMLRPCKeyedDecoder<Key>(node: node, path: codingPath))
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        // this should only work if the current node is "array"
        return try _XMLRPCUnkeyedDecoder(node: node, path: codingPath)
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return try _XMLRPCSingleValueDecoder(codingPath: codingPath, node: node)
    }
    
}

extension DecodingError {
    static func missingChildNode(_ node: XMLNode, _ name: String, _ path: [CodingKey]) -> DecodingError {
        let actual = node.xPath ?? "<missing>"
        let ctx = DecodingError.Context(codingPath: path, debugDescription: "Node \(actual) is missing a child named '\(name)")
        return .dataCorrupted(ctx)
    }
    static func missingChildNode(_ node: XMLNode, _ index: Int, _ path: [CodingKey]) -> DecodingError {
        let actual = node.xPath ?? "<missing>"
        let ctx = DecodingError.Context(codingPath: path, debugDescription: "Node \(actual) is missing a child at index '\(index)")
        return .dataCorrupted(ctx)
    }
    static func wrongNodeName(_ node: XMLNode, expected: String, _ path: [CodingKey]) -> DecodingError {
        let actual = node.xPath ?? "<missing>"
        let ctx = DecodingError.Context(codingPath: path, debugDescription: "Node \(actual) is not a named '\(expected)")
        return .dataCorrupted(ctx)
    }
    static func missingContents(_ node: XMLNode, _ path: [CodingKey]) -> DecodingError {
        let actual = node.xPath ?? "<missing>"
        let ctx = DecodingError.Context(codingPath: path, debugDescription: "Node \(actual) does not have any contents")
        return .dataCorrupted(ctx)
    }
    static func invalidContents(_ node: XMLNode, _ path: [CodingKey]) -> DecodingError {
        let actual = node.xPath ?? "<missing>"
        let ctx = DecodingError.Context(codingPath: path, debugDescription: "Node \(actual) has contents that cannot be interpreted")
        return .dataCorrupted(ctx)
    }
}
struct AnyCodingKey: CodingKey, ExpressibleByStringLiteral {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        guard let i = Int(stringValue) else { return nil }
        self.stringValue = stringValue
        self.intValue = i
    }
    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
    init(stringLiteral value: String) {
        self.stringValue = value
        self.intValue = Int(value)
    }
}

// this decodes a <struct>, which holds an array of <member /> nodes
private struct _XMLRPCKeyedDecoder<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let codingPath: [CodingKey]
    let allKeys: [Key]
    
    private let rootNode: XMLNode
    private let valueNodes: Dictionary<String, XMLNode>
    
    init(node: XMLNode, path: [CodingKey]) throws {
        let children = node.children ?? []
        let members = children.filter { $0.name == "member" }
        
        var map = Dictionary<String, XMLNode>()
        for member in members {
            guard let nameNode = member.child(at: 0) else { throw DecodingError.missingChildNode(node, 0, path) }
            guard nameNode.name == "name" else { throw DecodingError.wrongNodeName(nameNode, expected: "name", path) }
            guard let name = nameNode.stringValue else { throw DecodingError.missingContents(nameNode, path) }
            guard let valueNode = member.child(at: 1) else { throw DecodingError.missingChildNode(node, 1, path) }
            guard valueNode.name == "value" else { throw DecodingError.wrongNodeName(valueNode, expected: "value", path) }
            map[name] = valueNode
        }
        self.rootNode = node
        self.codingPath = path
        self.valueNodes = map
        self.allKeys = map.keys.compactMap(Key.init(stringValue:))
    }
    
    func contains(_ key: Key) -> Bool {
        return valueNodes.keys.contains(key.stringValue)
    }
    
    func decodeNil(forKey key: Key) throws -> Bool {
        let context = DecodingError.Context(codingPath: codingPath + [key], debugDescription: "XMLRPC does not support NULL values")
        throw DecodingError.typeMismatch(NSNull.self, context)
    }
    
    private func getSingleChild(_ key: Key) throws -> XMLNode {
        guard let valueNode = valueNodes[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: codingPath, debugDescription: "No member with name '\(key.stringValue)'"))
        }
        guard let child = valueNode.child(at: 0) else { throw DecodingError.missingChildNode(valueNode, 0, codingPath + [key]) }
        return child
    }
    private func getSingleChild(of key: Key, name: String) throws -> XMLNode {
        let child = try getSingleChild(key)
        guard name == child.name else { throw DecodingError.wrongNodeName(child, expected: name, codingPath + [key]) }
        return child
    }
    
    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        let child = try getSingleChild(key)
        return try _XMLRPCSingleValueDecoder(codingPath: codingPath + [key], node: child).decode(type)
    }
    
    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        let child = try getSingleChild(key)
        return try _XMLRPCSingleValueDecoder(codingPath: codingPath + [key], node: child).decode(type)
    }
    
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        let child = try getSingleChild(key)
        return try _XMLRPCSingleValueDecoder(codingPath: codingPath + [key], node: child).decode(type)
    }
    func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        let child = try getSingleChild(key)
        return try _XMLRPCSingleValueDecoder(codingPath: codingPath + [key], node: child).decode(type)
    }
    func decode(_ type: Date.Type, forKey key: Key) throws -> Date {
        let child = try getSingleChild(key)
        return try _XMLRPCSingleValueDecoder(codingPath: codingPath + [key], node: child).decode(type)
    }
    func decode(_ type: Data.Type, forKey key: Key) throws -> Data {
        let child = try getSingleChild(key)
        return try _XMLRPCSingleValueDecoder(codingPath: codingPath + [key], node: child).decode(type)
    }
    func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        let child = try getSingleChild(key)
        return try _XMLRPCSingleValueDecoder(codingPath: codingPath + [key], node: child).decode(type)
    }
    
    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        let child = try getSingleChild(key)
        return try _XMLRPCSingleValueDecoder(codingPath: codingPath + [key], node: child).decode(type)
    }
    
    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        let child = try getSingleChild(key)
        return try _XMLRPCSingleValueDecoder(codingPath: codingPath + [key], node: child).decode(type)
    }
    
    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        let child = try getSingleChild(key)
        return try _XMLRPCSingleValueDecoder(codingPath: codingPath + [key], node: child).decode(type)
    }
    
    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        let child = try getSingleChild(key)
        return try _XMLRPCSingleValueDecoder(codingPath: codingPath + [key], node: child).decode(type)
    }
    
    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        let child = try getSingleChild(key)
        return try _XMLRPCSingleValueDecoder(codingPath: codingPath + [key], node: child).decode(type)
    }
    
    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        let child = try getSingleChild(key)
        return try _XMLRPCSingleValueDecoder(codingPath: codingPath + [key], node: child).decode(type)
    }
    
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        let child = try getSingleChild(key)
        return try _XMLRPCSingleValueDecoder(codingPath: codingPath + [key], node: child).decode(type)
    }
    
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        let child = try getSingleChild(key)
        return try _XMLRPCSingleValueDecoder(codingPath: codingPath + [key], node: child).decode(type)
    }
    
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        let child = try getSingleChild(key)
        return try _XMLRPCSingleValueDecoder(codingPath: codingPath + [key], node: child).decode(type)
    }
    
    func decode<D: Decodable>(_ type: Array<D>.Type, forKey key: Key) throws -> Array<D> {
        let arrayNode = try getSingleChild(of: key, name: "array")
        let nested = _XMLRPCDecoder(node: arrayNode, path: codingPath + [key])
        return try Array<D>.init(from: nested)
    }
    
    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
        let structNode = try getSingleChild(of: key, name: "struct")
        let nested = _XMLRPCDecoder(node: structNode, path: codingPath + [key])
        return try T.init(from: nested)
    }
    
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        let valueNode = try getSingleChild(key)
        return try KeyedDecodingContainer(_XMLRPCKeyedDecoder<NestedKey>(node: valueNode, path: codingPath + [key]))
    }
    
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        let valueNode = try getSingleChild(key)
        return try _XMLRPCUnkeyedDecoder(node: valueNode, path: codingPath + [key])
    }
    
    func superDecoder() throws -> Decoder {
        return _XMLRPCDecoder(node: rootNode, path: codingPath)
    }
    
    func superDecoder(forKey key: Key) throws -> Decoder {
        return _XMLRPCDecoder(node: rootNode, path: codingPath)
    }
    
}

private struct _XMLRPCUnkeyedDecoder: UnkeyedDecodingContainer {
    private let root: XMLNode
    private let values: [XMLNode]
    
    let codingPath: [CodingKey]
    
    var count: Int? { values.count }
    var isAtEnd: Bool { currentIndex >= values.count }
    
    private(set) var currentIndex: Int = 0
    
    private var currentKey: CodingKey { AnyCodingKey(intValue: currentIndex)! }
    private var currentPath: [CodingKey] { codingPath + [currentKey] }
    
    private mutating func nextValue() throws -> (XMLNode, [CodingKey]) {
        let path = currentPath
        guard currentIndex >= 0 && currentIndex < values.count else {
            throw DecodingError.missingChildNode(root, currentIndex, path)
        }
        let v = values[currentIndex]
        currentIndex += 1
        return (v, path)
    }
    
    init(node: XMLNode, path: [CodingKey]) throws {
        guard node.name == "array" else { throw DecodingError.wrongNodeName(node, expected: "array", path) }
        let data = try node.child(at: 0) ?! DecodingError.missingChildNode(node, 0, path)
        guard data.name == "data" else { throw DecodingError.wrongNodeName(data, expected: "data", path) }
        root = node
        values = data.children ?? []
        codingPath = path
    }
    
    mutating func decodeNil() throws -> Bool {
        return false
    }
    
    mutating func decode(_ type: Bool.Type) throws -> Bool {
        let (v, path) = try nextValue()
        return try _XMLRPCSingleValueDecoder(codingPath: path, node: v).decode(type)
    }
    
    mutating func decode(_ type: String.Type) throws -> String {
        let (v, path) = try nextValue()
        return try _XMLRPCSingleValueDecoder(codingPath: path, node: v).decode(type)
    }
    
    mutating func decode(_ type: Double.Type) throws -> Double {
        let (v, path) = try nextValue()
        return try _XMLRPCSingleValueDecoder(codingPath: path, node: v).decode(type)
    }
    
    mutating func decode(_ type: Float.Type) throws -> Float {
        let (v, path) = try nextValue()
        return try _XMLRPCSingleValueDecoder(codingPath: path, node: v).decode(type)
    }
    
    mutating func decode(_ type: Int.Type) throws -> Int {
        let (v, path) = try nextValue()
        return try _XMLRPCSingleValueDecoder(codingPath: path, node: v).decode(type)
    }
    
    mutating func decode(_ type: Int8.Type) throws -> Int8 {
        let (v, path) = try nextValue()
        return try _XMLRPCSingleValueDecoder(codingPath: path, node: v).decode(type)
    }
    
    mutating func decode(_ type: Int16.Type) throws -> Int16 {
        let (v, path) = try nextValue()
        return try _XMLRPCSingleValueDecoder(codingPath: path, node: v).decode(type)
    }
    
    mutating func decode(_ type: Int32.Type) throws -> Int32 {
        let (v, path) = try nextValue()
        return try _XMLRPCSingleValueDecoder(codingPath: path, node: v).decode(type)
    }
    
    mutating func decode(_ type: Int64.Type) throws -> Int64 {
        let (v, path) = try nextValue()
        return try _XMLRPCSingleValueDecoder(codingPath: path, node: v).decode(type)
    }
    
    mutating func decode(_ type: UInt.Type) throws -> UInt {
        let (v, path) = try nextValue()
        return try _XMLRPCSingleValueDecoder(codingPath: path, node: v).decode(type)
    }
    
    mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
        let (v, path) = try nextValue()
        return try _XMLRPCSingleValueDecoder(codingPath: path, node: v).decode(type)
    }
    
    mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
        let (v, path) = try nextValue()
        return try _XMLRPCSingleValueDecoder(codingPath: path, node: v).decode(type)
    }
    
    mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
        let (v, path) = try nextValue()
        return try _XMLRPCSingleValueDecoder(codingPath: path, node: v).decode(type)
    }
    
    mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
        let (v, path) = try nextValue()
        return try _XMLRPCSingleValueDecoder(codingPath: path, node: v).decode(type)
    }
    
    mutating func decode(_ type: Date.Type) throws -> Date {
        let (v, path) = try nextValue()
        return try _XMLRPCSingleValueDecoder(codingPath: path, node: v).decode(type)
    }
    
    mutating func decode(_ type: Data.Type) throws -> Data {
        let (v, path) = try nextValue()
        return try _XMLRPCSingleValueDecoder(codingPath: path, node: v).decode(type)
    }
    
    mutating func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        let (v, path) = try nextValue()
        let decoder = _XMLRPCDecoder(node: v, path: path)
        return try T.init(from: decoder)
    }
    
    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        let (v, path) = try nextValue()
        return try KeyedDecodingContainer(_XMLRPCKeyedDecoder<NestedKey>(node: v, path: path))
    }
    
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        let (v, path) = try nextValue()
        return try _XMLRPCUnkeyedDecoder(node: v, path: path)
    }
    
    mutating func superDecoder() throws -> Decoder {
        return _XMLRPCDecoder(node: root, path: codingPath)
    }
    
    
}

private struct _XMLRPCSingleValueDecoder: SingleValueDecodingContainer {
    
    internal init(codingPath: [CodingKey], node: XMLNode) throws {
        var inner = node
        if node.name == "value" && node.childCount == 1 {
            inner = node.child(at: 0) ?? node
        }
        self.codingPath = codingPath
        self.node = inner
    }
    
    let codingPath: [CodingKey]
    let node: XMLNode
    
    private func assertNodeName(_ names: String...) throws {
        let name = try node.name ?! DecodingError.wrongNodeName(node, expected: names[0], codingPath)
        if names.contains(name) == false {
            throw DecodingError.wrongNodeName(node, expected: names[0], codingPath)
        }
    }
    
    private func stringContents() throws -> String {
        guard let string = node.stringValue else { throw DecodingError.missingContents(node, codingPath) }
        return string
    }
    
    func decodeNil() -> Bool { return false }
    
    func decode(_ type: Bool.Type) throws -> Bool {
        try assertNodeName("boolean")
        let contents = try stringContents()
        if contents == "1" { return true }
        if contents == "0" { return false }
        throw DecodingError.invalidContents(node, codingPath)
    }
    
    func decode(_ type: String.Type) throws -> String {
        try assertNodeName("string")
        return try stringContents()
    }
    
    func decode(_ type: Double.Type) throws -> Double {
        try assertNodeName("double")
        let contents = try stringContents()
        return try Double(contents) ?! DecodingError.invalidContents(node, codingPath)
    }
    
    func decode(_ type: Float.Type) throws -> Float {
        try assertNodeName("double")
        let contents = try stringContents()
        return try Float(contents) ?! DecodingError.invalidContents(node, codingPath)
    }
    
    func decode(_ type: Date.Type) throws -> Date {
        try assertNodeName("dateTime.iso8601")
        let contents = try stringContents()
        return try iso8601Formatter.date(from: contents) ?! DecodingError.invalidContents(node, codingPath)
    }
    
    func decode(_ type: Data.Type) throws -> Data {
        try assertNodeName("base64")
        let contents = try stringContents()
        return try Data(base64Encoded: contents) ?! DecodingError.invalidContents(node, codingPath)
    }
    
    private func decodeInt<I: FixedWidthInteger>() throws -> I {
        try assertNodeName("int", "i4")
        let contents = try stringContents()
        return try I(contents) ?! DecodingError.invalidContents(node, codingPath)
    }
    
    func decode(_ type: Int.Type) throws -> Int { try decodeInt() }
    func decode(_ type: Int8.Type) throws -> Int8 { try decodeInt() }
    func decode(_ type: Int16.Type) throws -> Int16 { try decodeInt() }
    func decode(_ type: Int32.Type) throws -> Int32 { try decodeInt() }
    func decode(_ type: Int64.Type) throws -> Int64 { try decodeInt() }
    func decode(_ type: UInt.Type) throws -> UInt { try decodeInt() }
    func decode(_ type: UInt8.Type) throws -> UInt8 { try decodeInt() }
    func decode(_ type: UInt16.Type) throws -> UInt16 { try decodeInt() }
    func decode(_ type: UInt32.Type) throws -> UInt32 { try decodeInt() }
    func decode(_ type: UInt64.Type) throws -> UInt64 { try decodeInt() }
    
    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        let decoder = _XMLRPCDecoder(node: node, path: codingPath)
        return try T.init(from: decoder)
    }
}
