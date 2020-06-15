//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/13/20.
//

import Foundation

extension XMLElement {
    convenience init(name: String, children: Array<XMLNode>) {
        self.init(name: name)
        for child in children {
            self.addChild(child)
        }
    }
    convenience init(name: String, child: XMLNode?) {
        self.init(name: name)
        if let c = child { self.addChild(c) }
    }
    
    @discardableResult
    func addElement(_ name: String, stringValue: String? = nil) -> XMLElement {
        let e = XMLElement(name: name, stringValue: stringValue)
        addChild(e)
        return e
    }
    
    @discardableResult
    func addElement(_ name: String, child: XMLNode) -> XMLElement {
        let e = XMLElement(name: name, child: child)
        addChild(e)
        return e
    }
    
    @discardableResult
    func addElement(_ name: String, children: Array<XMLNode>) -> XMLElement {
        let e = XMLElement(name: name, children: children)
        addChild(e)
        return e
    }
}
