import Vapor
import Foundation

public class WechatRouter: FederatedServiceRouter {
    public let tokens: FederatedServiceTokens
    public let callbackCompletion: (Request, String)throws -> (Future<ResponseEncodable>)
    public var scope: [String] = []
    public let callbackURL: String
    public let accessTokenURL: String = "https://api.weixin.qq.com/sns/oauth2/access_token"

    public required init(callback: String, completion: @escaping (Request, String)throws -> (Future<ResponseEncodable>)) throws {
        self.tokens = try WechatAuth()
        self.callbackURL = callback
        self.callbackCompletion = completion
    }
    
    public func authURL(_ request: Request) throws -> String {
        let escaped_callbackURL = self.callbackURL.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? "unknown_callback"
        return "https://open.weixin.qq.com/connect/oauth2/authorize?" +
            "appid=\(self.tokens.clientID)&" +
            "redirect_uri=\(escaped_callbackURL)&" +
            "response_type=code&" +
            "scope=\(scope.joined(separator: ","))&" +
            "state=STATE" + "#wechat_redirect"
            
    }
    
    public func fetchToken(from request: Request) throws -> Future<String> {
        let code: String
        if let queryCode: String = try request.query.get(at: "code") {
            code = queryCode
        } else if let error: String = try request.query.get(at: "error") {
            throw Abort(.badRequest, reason: error)
        } else {
            throw Abort(.badRequest, reason: "Missing 'code' key in URL query")
        }
        
        guard let url = URL(
            string: self.accessTokenURL.finished(with: "?") +
                    "appid=\(self.tokens.clientID)&" +
                    "secret=\(self.tokens.clientSecret)&" +
                    "code=\(code)&" +
                    "grant_type=authorization_code") else {
                        throw Abort(.internalServerError, reason: "Unable to convert String '\(self.accessTokenURL)' to URL")
        }
        
        return try request.client().get(url).flatMap(to: String.self) { response in
            return response.content.get(String.self, at: ["errcode"]).map(to: Int.self) { errnum in
                return Int(errnum) ?? 0
            }.flatMap(to: String.self) { errnum in
                if errnum > 0 {
                    
                    return response.content.get(String.self, at:["errmsg"]).map { errmsg in
                        throw Abort(.internalServerError, reason: "Unable get token: \(errnum), \(errmsg)")
                    }
                    
                }else{
                    return response.content.get(String.self, at: ["access_token"])
                }
            }
        }
    }
    
    public func callback(_ request: Request)throws -> Future<Response> {
        return try self.fetchToken(from: request).flatMap(to: ResponseEncodable.self) { accessToken in
            let session = try request.session()
            
            session.setAccessToken(accessToken)
            try session.set("access_token_service", to: OAuthService.wechat)
            
            return try self.callbackCompletion(request, accessToken)
        }.flatMap(to: Response.self) { response in
            return try response.encode(for: request)
        }
    }
}
