extension OAuthService {
    public static let wechat = OAuthService.init(
        name: "wechat",
        endpoints: [
            "user": "https://api.weixin.qq.com/sns/userinfo"
        ]
    )
}
