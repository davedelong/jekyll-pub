import Foundation

enum MovableType {

    struct GetCategories: XMLRPCMethod {
        typealias XMLRPCMethodResult = Array<JekyllCategory>
        static let methodCalls: Set<String> = ["mt.getCategoryList"]

        let blogID: String
        let userName: String
        let password: String

        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            blogID = try c.decode(String.self)
            userName = try c.decode(String.self)
            password = try c.decode(String.self)
        }

        func execute(with site: JekyllSite) throws -> Array<JekyllCategory> {
            return site.allCategories()
        }
    }

}
