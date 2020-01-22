import Vapor

public class WechatAuth: FederatedServiceTokens {
    public static var idEnvKey: String = "WECHAT_APP_ID"
    public static var secretEnvKey: String = "WECHAT_APP_SECRET"
    public var clientID: String
    public var clientSecret: String
    
    public required init() throws {
        let idError = ImperialError.missingEnvVar(WechatAuth.idEnvKey)
        let secretError = ImperialError.missingEnvVar(WechatAuth.secretEnvKey)
        
        self.clientID = try Environment.get(WechatAuth.idEnvKey).value(or: idError)
        self.clientSecret = try Environment.get(WechatAuth.secretEnvKey).value(or: secretError)
    }
}
