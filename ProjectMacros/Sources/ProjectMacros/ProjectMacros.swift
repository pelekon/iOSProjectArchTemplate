// The Swift Programming Language
// https://docs.swift.org/swift-book

@attached(member, names: named(CaseLabels))
public macro EnumCaseLabels() = #externalMacro(module: "Macros", type: "MakeSubEnumWithCasesMacro")

@attached(member, names: prefixed(Testable), named(AnyImpl))
public macro GenerateTestableImpl() = #externalMacro(module: "Macros", type: "GenerateTestableAbstractionMacro")

@attached(peer)
public macro IgnoreForImpl() = #externalMacro(module: "Macros", type: "IgnoreForAbstractionMacro")

@freestanding(declaration, names: arbitrary)
public macro GenerateKeyForImpl<T, each LiveParam, each TestableParam>(
    for type: T.Type, liveArgs: repeat each LiveParam, testableArgs: repeat each TestableParam
) = #externalMacro(module: "Macros", type: "GenerateAbstractionKeyMacro")

@attached(peer, names: prefixed(show), prefixed(hide), arbitrary)
public macro GenerateMutators<T>(name: String, coupledValueType: T.Type = Void.self) = #externalMacro(module: "Macros", type: "GenerateMutatorsMacro")

@attached(member, names: prefixed(bind), arbitrary)
public macro GenerateBindings(makeNonFunctionBindings: Bool = true) = #externalMacro(module: "Macros", type: "GenerateBindingsMacro")

@attached(peer)
public macro BindTarget<Object, each Value>(for: repeat (KeyPath<Object, each Value>, (each Value).Type)) = #externalMacro(module: "Macros", type: "BindTargetMacro")

@attached(peer)
public macro Bindable<Object, Value>(to: KeyPath<Object, Value>) = #externalMacro(module: "Macros", type: "BindableMacro")
