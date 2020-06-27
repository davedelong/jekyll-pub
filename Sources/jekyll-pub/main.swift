import Foundation

let argument = CommandLine.arguments.last ?? "."
let path = Path(stringLiteral: argument)

let site = JekyllSite(siteFolder: path)
let server = XMLRPCServer(site: site)
try server.run()
