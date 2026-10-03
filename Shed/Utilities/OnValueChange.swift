//
//  OnValueChange.swift
//  Shed
//
//  `onChange` whose closure signature changed in macOS 14; this picks the
//  right one so call sites work on Ventura too.
//

import SwiftUI

extension View {
    @ViewBuilder
    func onValueChange<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        if #available(macOS 14, *) {
            onChange(of: value) { _, newValue in action(newValue) }
        } else {
            onChange(of: value, perform: action)
        }
    }
}
