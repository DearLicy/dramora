# 参与贡献果幕

感谢你愿意帮助改进果幕。果幕是黄果短剧第三方客户端，不提供、不存储、不分发音视频内容；提交代码或反馈时，请同时尊重内容提供方与用户隐私。

## 提交 Issue 前

1. 先搜索现有 Issue，避免重复反馈。
2. 确认使用的是 [最新 Release](https://github.com/DearLicy/guomu/releases)。
3. 数据源问题请在设置页执行“同步地址”和“线路测速”，再附上当前线路与错误提示。
4. 不要提交账号密码、Bearer token、Cookie、私钥、签名证书或完整请求头。

## 开发环境

- Flutter `3.35.1` stable
- Dart `3.9.x`
- Android 24+ / iOS 15+

```bash
flutter pub get
flutter analyze
flutter test
python3 -m unittest discover -s tool/tests -p 'test_sync_sources.py'
```

涉及 Android、iOS 或数据源发现的修改，请说明实际验证的平台与结果；没有在真机验证的内容不要写成已验证。

## Pull Request

- 保持改动聚焦，一个 PR 解决一个明确问题。
- 修复数据源问题时优先使用真实接口和 `/api/home` 健康探测，不把临时可用域名写死成唯一入口。
- 新增或修改数据源逻辑时必须补充测试，并说明只读请求回退与写请求不重复提交的策略。
- 不提交 `.tmp/`、构建产物、签名文件、密钥或本地设备信息。
- 提交前至少运行 `flutter analyze` 和 `flutter test`；无法运行的检查请明确说明原因。
- UI 改动请附上浅色、深色或窄屏截图（适用时）。

## 行为约定

请阅读 [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)。技术分歧可以讨论，但请针对代码、接口和可复现证据，不对个人进行攻击或泄露隐私。

## 安全问题

请不要在公开 Issue 中披露可利用细节、凭据或安装签名材料，按 [SECURITY.md](SECURITY.md) 的方式私下报告。
