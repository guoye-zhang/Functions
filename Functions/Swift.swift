import Foundation

private let template = """
// DO NOT EDIT. Generated by funcgen.
import Foundation

private class EncoderRuntime {
    private var stack = [Function]()

    var level: Int {
        return stack.count - 1
    }

    var current: Function {
        get {
            return stack[level]
        }
        set {
            stack[level] = newValue
        }
    }

    func push() {
        stack.append(Function())
    }

    func pop() -> Function {
        return stack.removeLast()
    }

    static var runtime: EncoderRuntime {
        return Thread.current.threadDictionary.object(forKey: "edu.jhu.Functions.Runtime") as! EncoderRuntime
    }
}

protocol _Producer {
    var producer: Function.A { get }
}

extension Function.A {
    init(argumentNumber: Int) {
        level = UInt32(EncoderRuntime.runtime.level)
        step = Int32(-argumentNumber)
    }

    @discardableResult
    init(producer: Function.Producer.OneOf_Producer) {
        let runtime = EncoderRuntime.runtime
        level = UInt32(runtime.level)
        step = Int32(runtime.current.steps.count)
        var p = Function.Producer()
        p.producer = producer
        runtime.current.steps.append(p)
    }

    var producer: Function.A { return self }
}

extension Function: _Producer {
    var producer: Function.A {
        return Function.A(producer: .functionRaw(self))
    }
}\n\n
"""

struct Swift: Language {
    static let protobufTypeToNative = [
        "double": "Double", "float": "Float",
        "int32": "Int32", "int64": "Int64",
        "uint32": "UInt32", "uint64": "UInt64",
        "sint32": "Int32", "sint64": "Int64",
        "fixed32": "UInt32", "fixed64": "UInt64",
        "sfixed32": "Int32", "sfixed64": "Int64",
        "bool": "Bool",
        "string": "String", "bytes": "Data"
    ]
    
    func nativeType(for type: String) -> String {
        return Swift.protobufTypeToNative[type] ?? type
    }
    
    let parser: Parser
    
    private func writeCommaSeparated<T: Sequence>(_ sequence: T, to output: inout String, body: (T.Element) -> ()) {
        var first = true
        sequence.forEach {
            if !first { output.append(", ") } else { first = false }
            body($0)
        }
    }
    
    private func writeArgumentsExtension(to output: inout String) {
        for i in parser.argumentNumber.sorted() {
            if i == 0 { continue }
            output.append("extension Function.Producer.A\(i) {\n")
            output.append("    init(")
            writeCommaSeparated(1...i, to: &output) {
                output.append("_ o\($0): Function.A")
            }
            output.append(") {\n")
            for j in 1...i {
                output.append("        self.o\(j) = o\(j)\n")
            }
            output.append("    }\n}\n\n")
        }
    }
    
    private func writeBasicType(name: String, to output: inout String) {
        let native = Swift.protobufTypeToNative[name]
        let nativeName = native ?? name
        output.append("""
            protocol \(nativeName)Producer: _Producer {}
            
            extension Function.A: \(nativeName)Producer {}\n\n
            """)
        if native != nil {
            output.append("""
                extension \(nativeName): \(nativeName)Producer {
                    var producer: Function.A {
                        return Function.A(producer: .\(name)Raw(self))
                    }
                }\n\n
                """)
        }
    }
    
    private func writeFunctionType(name: String, functionType: Parser.FunctionType, to output: inout String) {
        output.append("""
            extension Function.A {
                var \(name): \(name)Producer {
                    return {
            """)
        if functionType.argumentTypes.count > 0 {
            output.append(" ")
            writeCommaSeparated(functionType.argumentTypes.indices, to: &output) {
                output.append("o\($0 + 1)")
            }
            output.append(" in")
        }
        output.append(" Function.A(producer: .\(name)(.init(self")
        for i in functionType.argumentTypes.indices {
            output.append(", o\(i + 1).producer")
        }
        output.append(")))")
        if let returnType = functionType.returnType, case .function = parser.typesMap[returnType]! {
            output.append(".\(returnType)")
        }
        output.append(" }\n    }\n}\n\n")
    }
    
    private func writeTypealias(name: String, functionType: Parser.FunctionType, to output: inout String) {
        // producer
        output.append("typealias \(name)Producer = (")
        writeCommaSeparated(functionType.argumentTypes, to: &output) {
            output.append("\(nativeType(for: $0))Producer")
        }
        if let type = functionType.returnType {
            output.append(") -> \(nativeType(for: type))Producer\n")
        } else {
            output.append(") -> ()\n")
        }
        
        // real
        output.append("typealias \(name) = (")
        writeCommaSeparated(functionType.argumentTypes, to: &output) {
            output.append("\(nativeType(for: $0))")
        }
        if let type = functionType.returnType {
            output.append(") -> \(nativeType(for: type))\n\n")
        } else {
            output.append(") -> ()\n\n")
        }
    }
    
    private func writeSymbol(name: String, functionType: Parser.FunctionType, to output: inout String) {
        output.append("func \(name)(")
        writeCommaSeparated(functionType.argumentTypes.enumerated(), to: &output) {
            output.append("_ o\($0.offset + 1): \(nativeType(for: $0.element))Producer")
        }
        if let type = functionType.returnType {
            output.append(") -> \(nativeType(for: type))Producer {\n")
        } else {
            output.append(") {\n")
        }
        output.append("    return Function.A(producer: .\(name)(.init(")
        writeCommaSeparated(functionType.argumentTypes.enumerated(), to: &output) {
            if case .function? = parser.typesMap[$0.element] {
                output.append("\($0.element)EncodeInternal(o\($0.offset + 1)).producer")
            } else {
                output.append("o\($0.offset + 1).producer")
            }
        }
        output.append(")))")
        if let returnType = functionType.returnType, case .function = parser.typesMap[returnType]! {
            output.append(".\(returnType)")
        }
        output.append("\n}\n\n")
    }
    
    private func writeEncode(name: String, to output: inout String) {
        output.append("""
            func \(name)Encode(_ function: \(name)Producer) -> Function {
                Thread.current.threadDictionary.setObject(EncoderRuntime(), forKey: "edu.jhu.Functions.Runtime" as NSString)
                defer {
                    Thread.current.threadDictionary.removeObject(forKey: "edu.jhu.Functions.Runtime")
                }
                return \(name)EncodeInternal(function)
            }\n\n
            """)
    }
    
    private func writeEncodeInternal(name: String, functionType: Parser.FunctionType, to output: inout String) {
        output.append("""
            private func \(name)EncodeInternal(_ function: \(name)Producer) -> Function {
                let runtime = EncoderRuntime.runtime
                runtime.push()\n
            """)
        if let returnType = functionType.returnType {
            output.append("    let returnStep = function(")
            writeCommaSeparated(functionType.argumentTypes.indices, to: &output) {
                output.append("Function.A(argumentNumber: \($0 + 1))")
            }
            if case .function? = parser.typesMap[returnType] {
                output.append(")\n    runtime.current.returnStep = \(returnType)EncodeInternal(returnStep).producer\n")
            } else {
                output.append(")\n    runtime.current.returnStep = returnStep.producer\n")
            }
        } else {
            output.append("    function(")
            writeCommaSeparated(functionType.argumentTypes.indices, to: &output) {
                output.append("Function.A(argumentNumber: \($0 + 1))")
            }
            output.append(")\n")
        }
        
        output.append("    return runtime.pop()\n}\n\n")
    }
    
    private func writeDecode(name: String, functionType: Parser.FunctionType, to output: inout String) {
        output.append("""
            func \(name)Decode(function: Function, symbols: Symbols) -> \(name) {
                let decoderRuntime = DecoderRuntime()
                return {
            """)
        if functionType.argumentTypes.count > 0 {
            output.append(" ")
            writeCommaSeparated(functionType.argumentTypes.indices, to: &output) {
                output.append("o\($0 + 1)")
            }
            output.append(" in")
        }
        if let type = functionType.returnType, case .function? = parser.typesMap[type] {
            output.append("\n        let result = decoderRuntime.run(function: function, symbols: symbols, arguments: [")
            writeCommaSeparated(functionType.argumentTypes.indices, to: &output) {
                output.append("o\($0 + 1)")
            }
            output.append("""
                ])
                        if let function = result as? ([Any]) -> Any {
                            return \(type)Run(function)
                        } else {
                            return result as! \(type)
                        }
                    }
                }\n\n
                """)
        } else {
            output.append(" decoderRuntime.run(function: function, symbols: symbols, arguments: [")
            writeCommaSeparated(functionType.argumentTypes.indices, to: &output) {
                output.append("o\($0 + 1)")
            }
            if let type = functionType.returnType {
                output.append("]) as! \(nativeType(for: type)) }\n}\n\n")
            } else {
                output.append("]) }\n}\n\n")
            }
        }
    }
    
    private func writeRun(name: String, functionType: Parser.FunctionType, to output: inout String) {
        output.append("private func \(name)Run(_ function: @escaping ([Any]) -> Any) -> \(name) {\n    return { ")
        if functionType.argumentTypes.count > 0 {
            writeCommaSeparated(functionType.argumentTypes.indices, to: &output) {
                output.append("o\($0 + 1)")
            }
            output.append(" in ")
        }
        if functionType.returnType == nil {
            output.append("_ = ")
        }
        output.append("function([")
        writeCommaSeparated(functionType.argumentTypes.indices, to: &output) {
            output.append("o\($0 + 1)")
        }
        if let type = functionType.returnType {
            output.append("]) as! \(nativeType(for: type)) }\n}\n\n")
        } else {
            output.append("]) }\n}\n\n")
        }
    }
    
    private func writeSymbolsProtocol(to output: inout String) {
        output.append("protocol Symbols {\n")
        for (name, functionType) in parser.symbols {
            output.append("    func \(name)(")
            writeCommaSeparated(functionType.argumentTypes.enumerated(), to: &output) {
                output.append("_ o\($0.offset + 1): \(nativeType(for: $0.element))")
            }
            if let type = functionType.returnType {
                output.append(") -> \(nativeType(for: type))\n")
            } else {
                output.append(") -> ()\n")
            }
        }
        output.append("}\n\n")
    }
    
    private func writeDecoder(to output: inout String) {
        output.append("""
            private class DecoderRuntime {
                private class Runtime {
                    var results = [Int: Any]()
                    let arguments: [Any]
                    init(arguments: [Any]) {
                        self.arguments = arguments
                    }
                }

                private func value(_ a: Function.A, in stack: [Runtime]) -> Any {
                    if a.step >= 0 {
                        return stack[Int(a.level)].results[Int(a.step)]!
                    } else {
                        return stack[Int(a.level)].arguments[Int(-a.step - 1)]
                    }
                }\n\n
            """)
        for (name, type) in parser.types {
            if case .function(let functionType) = type {
                output.append("""
                        private func \(name)Value(_ a: Function.A, in stack: [Runtime], symbols: Symbols) -> \(name) {
                            let raw = value(a, in: stack)
                            if let function = raw as? Function {
                                return { self.run(function: function, symbols: symbols, stack: stack + [Runtime(arguments: [
                    """)
                writeCommaSeparated(functionType.argumentTypes.indices, to: &output) {
                    output.append("$\($0)")
                }
                if let type = functionType.returnType {
                    output.append("])]) as! \(nativeType(for: type)) }\n")
                } else {
                    output.append("])]) }\n")
                }
                output.append("""
                            } else {
                                return raw as! \(name)
                            }
                        }\n\n
                    """)
            }
        }
        output.append("""
                private func run(function: Function, symbols: Symbols, stack: [Runtime]) -> Any {
                    let runtime = stack.last!
                    for (i, step) in function.steps.enumerated() {
                        switch step.producer! {
                        case .functionRaw(let raw):
                            runtime.results[i] = raw\n
            """)
        for (name, type) in parser.types {
            switch type {
            case .basic:
                output.append("""
                                case .\(name)Raw(let raw):
                                    runtime.results[i] = raw\n
                    """)
            case .function(let functionType):
                output.append("            case .\(name)(let a):\n                ")
                if functionType.returnType != nil {
                    output.append("runtime.results[i] = \(name)Value(a.o1, in: stack, symbols: symbols)(")
                } else {
                    output.append("\(name)Value(a.o1, in: stack, symbols: symbols)(")
                }
                writeCommaSeparated(functionType.argumentTypes.enumerated(), to: &output) {
                    if case .function? = parser.typesMap[$0.element] {
                        output.append("\($0.element)Value(a.o\($0.offset + 2), in: stack, symbols: symbols)")
                    } else {
                        output.append("value(a.o\($0.offset + 2), in: stack) as! \(nativeType(for: $0.element))")
                    }
                }
                output.append(")\n")
            }
        }
        
        for (name, functionType) in parser.symbols {
            if functionType.argumentTypes.count > 0 {
                output.append("            case .\(name)(let a):\n                ")
            } else {
                output.append("            case .\(name):\n                ")
            }
            if functionType.returnType != nil {
                output.append("runtime.results[i] = symbols.\(name)(")
            } else {
                output.append("symbols.\(name)(")
            }
            writeCommaSeparated(functionType.argumentTypes.enumerated(), to: &output) {
                if case .function? = parser.typesMap[$0.element] {
                    output.append("\($0.element)Value(a.o\($0.offset + 1), in: stack, symbols: symbols)")
                } else {
                    output.append("value(a.o\($0.offset + 1), in: stack) as! \(nativeType(for: $0.element))")
                }
            }
            output.append(")\n")
        }
        output.append("""
                        }
                    }
                    let returnValue = value(function.returnStep, in: stack)
                    if let function = returnValue as? Function {
                        return { self.run(function: function, symbols: symbols, stack: stack + [Runtime(arguments: $0)]) }
                    } else {
                        return returnValue
                    }
                }

                @discardableResult
                func run(function: Function, symbols: Symbols, arguments: [Any]) -> Any {
                    return run(function: function, symbols: symbols, stack: [Runtime(arguments: arguments)])
                }
            }
            """)
    }
    
    func generate(_ url: URL) {
        var output = template
        
        writeArgumentsExtension(to: &output)
        
        for (name, type) in parser.types {
            switch type {
            case .basic:
                writeBasicType(name: name, to: &output)
            case .function(let functionType):
                writeTypealias(name: name, functionType: functionType, to: &output)
                writeFunctionType(name: name, functionType: functionType, to: &output)
                writeEncodeInternal(name: name, functionType: functionType, to: &output)
                writeDecode(name: name, functionType: functionType, to: &output)
                writeRun(name: name, functionType: functionType, to: &output)
            }
        }
        
        for (name, functionType) in parser.symbols {
            writeSymbol(name: name, functionType: functionType, to: &output)
        }
        
        for (name, functionType) in parser.functions {
            writeTypealias(name: name, functionType: functionType, to: &output)
            writeEncode(name: name, to: &output)
            writeEncodeInternal(name: name, functionType: functionType, to: &output)
            writeDecode(name: name, functionType: functionType, to: &output)
        }
        
        writeSymbolsProtocol(to: &output)
        
        writeDecoder(to: &output)
        
        try! output.write(to: url, atomically: true, encoding: .utf8)
    }
}
