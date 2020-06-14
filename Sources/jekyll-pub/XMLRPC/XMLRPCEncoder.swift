//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/14/20.
//

import Foundation


class XMLRPCEncoder {
    init() { }
    func encode<T: Encodable>(_ value: T) throws -> Data {
        let root = XMLElement(name: "methodResponse")
        
        do {
            if let fault = value as? XMLRPCFault { throw fault }
            let parent = XMLElement(name: "param")
            var valueEncoder = _XMLRPCValueEncoder(parent: parent, codingPath: [])
            try valueEncoder.encode(value)
            
            let params = XMLElement(name: "params", child: parent)
            root.addChild(params)
        } catch let fault as XMLRPCFault {
            let parent = XMLElement(name: "fault")
            root.addChild(parent)
            var valueEncoder = _XMLRPCValueEncoder(parent: parent, codingPath: [])
            try valueEncoder.encode(fault)
        } catch {
            let string = XMLElement(name: "string", stringValue: error.localizedDescription)
            let value = XMLElement(name: "value", child: string)
            let fault = XMLElement(name: "fault", child: value)
            root.addChild(fault)
        }
        
        let document = XMLDocument(rootElement: root)
        document.version = "1.0"
        document.characterEncoding = "UTF-8"
        return document.xmlData(options: [.documentIncludeContentTypeDeclaration])
    }
}

private struct _XMLRPCEncoder: Encoder {
    let parent: XMLElement
    let codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { [:] }
    
    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        let container = _XMLRPCKeyedValueEncoder<Key>(parent: parent, codingPath: codingPath)
        return KeyedEncodingContainer(container)
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        return _XMLRPCUnkeyedValueEncoder(parent: parent, codingPath: codingPath)
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        return _XMLRPCValueEncoder(parent: parent, codingPath: codingPath)
    }
}

extension EncodingError {
    static func cannotEncode(_ value: Any, parent: XMLNode, _ path: [CodingKey]) -> EncodingError {
        let actual = parent.xPath ?? parent.name ?? "<<unknown>>"
        let ctx = EncodingError.Context(codingPath: path, debugDescription: "Unable to encode \(value) at \(actual)")
        return .invalidValue(value, ctx)
    }
    static func valueAlreadyEncoded(_ newValue: Any, parent: XMLNode, _ path: [CodingKey]) -> EncodingError {
        let actual = parent.xPath ?? parent.name ?? "<<unknown>>"
        let ctx = EncodingError.Context(codingPath: path, debugDescription: "Node \(actual) already has children: \(parent.children ?? [])")
        return .invalidValue(newValue, ctx)
    }
    static func duplicateKey(_ key: CodingKey, _ value: Any, parent: XMLNode, _ path: [CodingKey]) -> EncodingError {
        let actual = parent.xPath ?? parent.name ?? "<<unknown>>"
        let ctx = EncodingError.Context(codingPath: path, debugDescription: "A value for \(key) has already been encoded in \(actual)")
        return .invalidValue(value, ctx)
    }
}

private struct _XMLRPCValueEncoder: SingleValueEncodingContainer {
    let parent: XMLElement
    var codingPath: [CodingKey]
    
    init(parent: XMLElement, codingPath: [CodingKey]) {
        var actualParent = parent
        if actualParent.name != "value" {
            let value = XMLElement(name: "value")
            parent.addChild(value)
            actualParent = value
        }
        self.parent = actualParent
        self.codingPath = codingPath
    }
    
    private mutating func encodeString(_ string: String, node: String) throws {
        guard parent.childCount == 0 else {
            throw EncodingError.valueAlreadyEncoded(string, parent: parent, codingPath)
        }
        let element = XMLElement(name: node, stringValue: string)
        parent.addChild(element)
    }
    
    mutating func encodeNil() throws { throw EncodingError.cannotEncode(NSNull(), parent: parent, codingPath) }
    
    mutating func encode<T>(_ value: T) throws where T : Encodable {
        guard parent.childCount == 0 else {
            throw EncodingError.valueAlreadyEncoded(value, parent: parent, codingPath)
        }
        var toEncode: (String, String)?
        switch value {
            case let v as Date: toEncode = ("dateTime.iso8601", iso8601Formatter.string(from: v))
            case let s as String: toEncode = ("string", s)
            case let b as Bool: toEncode = ("boolean", b ? "1" : "0")
            case let d as Data: toEncode = ("base64", try d.base64EncodedString() ?! EncodingError.cannotEncode(value, parent: parent, codingPath))
            case let d as Double: toEncode = ("double", "\(d)")
            case let f as Float: toEncode = ("double", "\(f)")
            case let i as Int: toEncode = ("int", "\(i)")
            case let i as Int8: toEncode = ("int", "\(i)")
            case let i as Int16: toEncode = ("int", "\(i)")
            case let i as Int32: toEncode = ("int", "\(i)")
            case let i as Int64: toEncode = ("int", "\(i)")
            case let i as UInt: toEncode = ("int", "\(i)")
            case let i as UInt8: toEncode = ("int", "\(i)")
            case let i as UInt16: toEncode = ("int", "\(i)")
            case let i as UInt32: toEncode = ("int", "\(i)")
            case let i as UInt64: toEncode = ("int", "\(i)")
            default: break
        }
        if let (name, value) = toEncode {
            try encodeString(value, node: name)
        } else {
            let encoder = _XMLRPCEncoder(parent: parent, codingPath: codingPath)
            try value.encode(to: encoder)
        }
    }
    
}

private struct _XMLRPCUnkeyedValueEncoder: UnkeyedEncodingContainer {
    
    var codingPath: [CodingKey]
    var count: Int { data.childCount }
    
    private let root: XMLElement
    private let data: XMLElement
    private var currentPath: [CodingKey] { codingPath + [AnyCodingKey(intValue: count)!] }
    
    init(parent: XMLElement, codingPath: [CodingKey]) {
        self.root = parent
        self.data = XMLElement(name: "data")
        self.codingPath = codingPath
        
        let array = XMLElement(name: "array", child: data)
        parent.addChild(array)
    }
    
    mutating func encodeNil() throws { throw EncodingError.cannotEncode(NSNull(), parent: data, codingPath) }
    
    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        let value = XMLElement(name: "value")
        let path = currentPath
        
        data.addChild(value)
        let container = _XMLRPCKeyedValueEncoder<NestedKey>(parent: value, codingPath: path)
        return KeyedEncodingContainer(container)
    }
    
    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let value = XMLElement(name: "value")
        let path = currentPath
        data.addChild(value)
        return _XMLRPCUnkeyedValueEncoder(parent: value, codingPath: path)
    }
    
    mutating func superEncoder() -> Encoder {
        _XMLRPCEncoder(parent: root, codingPath: codingPath)
    }
    
    mutating func encode<T>(_ value: T) throws where T : Encodable {
        let valueNode = XMLElement(name: "value")
        let path = currentPath
        data.addChild(valueNode)
        var encoder = _XMLRPCValueEncoder(parent: valueNode, codingPath: path)
        try encoder.encode(value)
    }
    
}

private struct _XMLRPCKeyedValueEncoder<Key: CodingKey>: KeyedEncodingContainerProtocol {
    let root: XMLElement
    
    let container: XMLElement
    var codingPath: [CodingKey]
    private var keys = Set<String>()
    
    init(parent: XMLElement, codingPath: [CodingKey]) {
        self.root = parent
        self.codingPath = codingPath
        
        let structNode = XMLElement(name: "struct")
        root.addChild(structNode)
        
        self.container = structNode
    }
    
    private mutating func claimKey(_ key: Key, for value: Any) throws {
        if keys.contains(key.stringValue) {
            throw EncodingError.duplicateKey(key, value, parent: container, codingPath)
        }
        keys.insert(key.stringValue)
    }
    
    mutating func encodeNil(forKey key: Key) throws { throw EncodingError.cannotEncode(NSNull(), parent: container, codingPath + [key]) }
    
    mutating func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable {
        try claimKey(key, for: value)
        let member = XMLElement(name: "member")
        container.addChild(member)
        var encoder = _XMLRPCValueEncoder(parent: member, codingPath: codingPath + [key])
        try encoder.encode(value)
        
        let name = XMLElement(name: "name", stringValue: key.stringValue)
        member.insertChild(name, at: 0)
    }
    
    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        try! claimKey(key, for: "KeyedEncodingContainer<\(keyType)>")
        let member = XMLElement(name: "member")
        let name = XMLElement(name: "name", stringValue: key.stringValue)
        member.addChild(name)
        let value = XMLElement(name: "value")
        member.addChild(value)
        
        let container = _XMLRPCKeyedValueEncoder<NestedKey>(parent: value, codingPath: codingPath + [key])
        return KeyedEncodingContainer(container)
    }
    
    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        try! claimKey(key, for: "UnkeyedEncodingContainer")
        let member = XMLElement(name: "member")
        let name = XMLElement(name: "name", stringValue: key.stringValue)
        member.addChild(name)
        let value = XMLElement(name: "value")
        member.addChild(value)
        
        return _XMLRPCUnkeyedValueEncoder(parent: value, codingPath: codingPath + [key])
    }
    
    mutating func superEncoder() -> Encoder {
        return _XMLRPCEncoder(parent: root, codingPath: codingPath)
    }
    
    mutating func superEncoder(forKey key: Key) -> Encoder {
        return _XMLRPCEncoder(parent: root, codingPath: codingPath)
    }
    
    
}
