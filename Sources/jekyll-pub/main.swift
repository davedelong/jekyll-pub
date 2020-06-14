import Foundation

let site = JekyllSite(siteFolder: "~/Documents/davedelong.com")
let server = XMLRPCServer(site: site)
try server.run()
