//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/13/20.
//

import Foundation

infix operator ?!: NilCoalescingPrecedence

func ?!<T>(lhs: T?, rhs: @autoclosure () -> Error) throws -> T {
    if let value = lhs {
        return value
    } else {
        throw rhs()
    }
}
