import Foundation

let site = JekyllSite(
    id: "davedelong",
    siteFolder: URL(fileURLWithPath: "/Users/dave/Documents/davedelong.com")
)

let server = MetaWeblog(sites: [site])
try server.run()
