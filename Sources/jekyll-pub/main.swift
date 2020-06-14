import Foundation

let site = JekyllSite(siteFolder: "~/Documents/davedelong.com")
let server = MetaWeblog(site: site)
try server.run()
