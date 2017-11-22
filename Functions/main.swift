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

FileManager.default.changeCurrentDirectoryPath(url.deletingLastPathComponent().path)
let filename = URL(fileURLWithPath: url.deletingPathExtension().lastPathComponent)

let parser = Parser()
parser.parse(content)
Protobuf(parser: parser).generate(filename.appendingPathExtension("proto"))
Swift(parser: parser).generate(filename.appendingPathExtension("swift"))
