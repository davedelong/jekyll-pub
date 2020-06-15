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
            let param = XMLElement(name: "param")
            var valueEncoder = _XMLRPCValueEncoder(parent: param, codingPath: [])
            try valueEncoder.encode(value)
            
            root.addElement("params", child: param)
        } catch let fault as XMLRPCFault {
            let faultNode = root.addElement("fault")
            var valueEncoder = _XMLRPCValueEncoder(parent: faultNode, codingPath: [])
            try valueEncoder.encode(fault)
        } catch {
            let fault = root.addElement("fault")
            let value = fault.addElement("value")
            value.addElement("string", stringValue: error.localizedDescription)
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
            actualParent = parent.addElement("value")
        }
        self.parent = actualParent
        self.codingPath = codingPath
    }
    
    private mutating func encodeString(_ string: String, node: String) throws {
        guard parent.childCount == 0 else {
            throw EncodingError.valueAlreadyEncoded(string, parent: parent, codingPath)
        }
        parent.addElement(node, stringValue: string)
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
        
        parent.addElement("array", child: data)
    }
    
    mutating func encodeNil() throws { throw EncodingError.cannotEncode(NSNull(), parent: data, codingPath) }
    
    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        let path = currentPath
        let value = data.addElement("value")
        let container = _XMLRPCKeyedValueEncoder<NestedKey>(parent: value, codingPath: path)
        return KeyedEncodingContainer(container)
    }
    
    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let path = currentPath
        let value = data.addElement("value")
        return _XMLRPCUnkeyedValueEncoder(parent: value, codingPath: path)
    }
    
    mutating func superEncoder() -> Encoder {
        _XMLRPCEncoder(parent: root, codingPath: codingPath)
    }
    
    mutating func encode<T>(_ value: T) throws where T : Encodable {
        let path = currentPath
        let valueNode = data.addElement("value")
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
        
        self.container = root.addElement("struct")
    }
    
    private mutating func claimKey(_ key: Key, for value: Any) throws {
        if keys.contains(key.stringValue) {
            throw EncodingError.duplicateKey(key, value, parent: container, codingPath)
        }
        keys.insert(key.stringValue)
    }
    
    mutating func encodeNil(forKey key: Key) throws { }
    
    mutating func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable {
        try claimKey(key, for: value)
        let member = container.addElement("member")
        var encoder = _XMLRPCValueEncoder(parent: member, codingPath: codingPath + [key])
        try encoder.encode(value)
        
        let name = XMLElement(name: "name", stringValue: key.stringValue)
        member.insertChild(name, at: 0)
    }
    
    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        try! claimKey(key, for: "KeyedEncodingContainer<\(keyType)>")
        let member = container.addElement("member")
        member.addElement("name", stringValue: key.stringValue)
        let value = member.addElement("value")
        
        let container = _XMLRPCKeyedValueEncoder<NestedKey>(parent: value, codingPath: codingPath + [key])
        return KeyedEncodingContainer(container)
    }
    
    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        try! claimKey(key, for: "UnkeyedEncodingContainer")
        let member = container.addElement("member")
        member.addElement("name", stringValue: key.stringValue)
        let value = member.addElement("value")
        
        return _XMLRPCUnkeyedValueEncoder(parent: value, codingPath: codingPath + [key])
    }
    
    mutating func superEncoder() -> Encoder {
        return _XMLRPCEncoder(parent: root, codingPath: codingPath)
    }
    
    mutating func superEncoder(forKey key: Key) -> Encoder {
        return _XMLRPCEncoder(parent: root, codingPath: codingPath)
    }
    
    
}
