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
}
