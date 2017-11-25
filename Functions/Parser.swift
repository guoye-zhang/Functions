import Foundation

extension String {
    var isValidIdentifier: Bool {
        return unicodeScalars.first.map(CharacterSet.decimalDigits.contains) == false && rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) == nil
    }
}

class Parser {
    struct FunctionType {
        let argumentTypes: [String]
        let returnType: String?
    }
    
    enum DeclarationType {
        case basic(backed: Bool)
        case function(FunctionType)
    }
    
    private enum Section: String {
        case imports = "Import:"
        case types = "Type:"
        case subtypes = "Subtype:"
        case symbols = "Symbol:"
        case functions = "Function:"
    }
    
    private var current: Section? = nil
    var imports = [String]()
    var types = [(String, DeclarationType)]()
    var typesMap = [String: DeclarationType]()
    var subtypes = [(String, String)]()
    var subtypesMap = [String: [String]]()
    var symbols = [(String, FunctionType)]()
    var functions = [(String, FunctionType)]()
    var argumentNumber = Set<Int>()
    
    private func parse(signature: String, i: Int) -> FunctionType {
        let parts = signature.components(separatedBy: "->")
        let returnType: String?
        switch parts.count {
        case 1:
            returnType = nil
        case 2:
            let returnTypeName = parts[1].trimmingCharacters(in: .whitespaces)
            if typesMap[returnTypeName] == nil {
                types.append((returnTypeName, .basic(backed: false)))
                typesMap[returnTypeName] = .basic(backed: false)
            }
            returnType = returnTypeName
        default:
            fatalError("Line \(i): More than one '->'")
        }
        var argumentString = parts[0].trimmingCharacters(in: .whitespaces)
        let first = argumentString.removeFirst(), last = argumentString.removeLast()
        if first != "(" || last != ")" {
            fatalError("Line \(i): Arguments must be inside ()")
        }
        var argumentTypes = [String]()
        if !argumentString.trimmingCharacters(in: .whitespaces).isEmpty {
            for typeName in argumentString.components(separatedBy: ",") {
                let typeName = typeName.trimmingCharacters(in: .whitespaces)
                if typesMap[typeName] == nil {
                    types.append((typeName, .basic(backed: false)))
                    typesMap[typeName] = .basic(backed: false)
                }
                argumentTypes.append(typeName)
            }
        }
        return FunctionType(argumentTypes: argumentTypes, returnType: returnType)
    }
    
    func parse(_ content: String) {
        for (i, var line) in content.split(separator: "\n").enumerated() {
            let i = i + 1
            if let commentIndex = line.index(of: "#") {
                line = line[line.startIndex..<commentIndex]
            }
            let line = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            if let section = Section(rawValue: line) {
                current = section
                continue
            }
            guard let current = current else {
                fatalError("Line \(i): Section header expected")
            }
            switch current {
            case .imports:
                let url = URL(fileURLWithPath: line)
                guard (try? url.checkResourceIsReachable()) == true else {
                    fatalError("Line \(i): Import not found")
                }
                imports.append(line)
            case .types:
                if let index = line.index(of: "=") {
                    let name = line[line.startIndex..<index].trimmingCharacters(in: .whitespaces)
                    let type = line[line.index(after: index)..<line.endIndex].trimmingCharacters(in: .whitespaces)
                    if !name.isValidIdentifier {
                        fatalError("Line \(i): Type name invalid")
                    }
                    let functionType = parse(signature: type, i: i)
                    argumentNumber.insert(functionType.argumentTypes.count + 1)
                    types.append((name, .function(functionType)))
                    typesMap[name] = .function(functionType)
                } else {
                    if !line.isValidIdentifier {
                        fatalError("Line \(i): Type name invalid")
                    }
                    types.append((line, .basic(backed: true)))
                    typesMap[line] = .basic(backed: true)
                }
            case .subtypes:
                let parts = line.components(separatedBy: "<:")
                if parts.count != 2 {
                    fatalError("Line \(i): Subtype invalid")
                }
                let subtype = parts[0].trimmingCharacters(in: .whitespaces)
                let type = parts[1].trimmingCharacters(in: .whitespaces)
                if !subtype.isValidIdentifier || !type.isValidIdentifier {
                    fatalError("Line \(i): Type name invalid")
                }
                if typesMap[subtype] == nil {
                    types.append((subtype, .basic(backed: false)))
                    typesMap[subtype] = .basic(backed: false)
                }
                if typesMap[type] == nil {
                    types.append((type, .basic(backed: false)))
                    typesMap[type] = .basic(backed: false)
                }
                subtypes.append((subtype, type))
                subtypesMap[subtype, default: []].append(type)
            case .symbols:
                guard let index = line.index(of: "(") else {
                    fatalError("Line \(i): Expecting (")
                }
                let name = line[line.startIndex..<index].trimmingCharacters(in: .whitespaces)
                let type = line[index..<line.endIndex].trimmingCharacters(in: .whitespaces)
                if !name.isValidIdentifier {
                    fatalError("Line \(i): Symbol name invalid")
                }
                let functionType = parse(signature: type, i: i)
                argumentNumber.insert(functionType.argumentTypes.count)
                symbols.append((name, functionType))
            case .functions:
                guard let index = line.index(of: ":") else {
                    fatalError("Line \(i): Expecting (")
                }
                let name = line[line.startIndex..<index].trimmingCharacters(in: .whitespaces)
                let type = line[line.index(after: index)..<line.endIndex].trimmingCharacters(in: .whitespaces)
                if !name.isValidIdentifier {
                    fatalError("Line \(i): Symbol name invalid")
                }
                let functionType = parse(signature: type, i: i)
                functions.append((name, functionType))
            }
        }
    }
}
