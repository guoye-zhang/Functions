import Foundation

guard CommandLine.argc == 2 else {
    print("Usage: funcgen [spec]")
    exit(1)
}
let url = URL(fileURLWithPath: CommandLine.arguments[1])
guard let content = try? String(contentsOf: url) else {
    print("File not found")
    exit(1)
}

protocol Language {
    static var protobufTypeToNative: [String: String] { get }
}

let parser = Parser()
parser.parse(content)
let protobufURL = url.deletingPathExtension().appendingPathExtension("proto")
Protobuf(parser: parser).generate(protobufURL)
let swiftURL = url.deletingPathExtension().appendingPathExtension("swift")
Swift(parser: parser).generate(swiftURL)
