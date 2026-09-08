# Codex 实用方案库

一个面向普通用户、Windows 用户和初学开发者的中文实用方案库。每个方案都回答一个具体问题，并在发布前经过隔离测试、隐私检查和人工可读性检查。

> 这是非官方社区项目，与 OpenAI 无隶属、背书或维护关系。Codex 的能力和界面可能变化，涉及产品功能时以官方文档为准。

## 发布标准

- 一个方案只解决一个明确问题，不写空泛宣传。
- 必须包含可直接复制的中文提示词、操作步骤、失败处理和能力边界。
- 示例代码或脚本必须能够审查，并在安全的临时环境中测试。
- 测试结果必须脱敏；测试失败、证据不足或风险不可控时不发布。
- 不提交令牌、Cookie、代理凭据、个人路径、聊天内容或来源不明的二进制文件。

## 方案目录

<!-- SOLUTIONS_TABLE_START -->

| 日期 | 实用问题 | 分类 | 难度 | 测试状态 |
|---|---|---|---|---|
| 2026-09-08 | [上传 GitHub 前检查 ZIP 是否泄露隐私](solutions/2026-09-08-audit-zip-privacy/README.md) | 隐私和安全检查 | 小白 | 18 项测试通过 |

<!-- SOLUTIONS_TABLE_END -->

## 分类

- Windows 与文件处理
- GitHub 与开源发布
- 隐私和安全检查
- 文档、表格与内容整理
- 编程、调试与项目维护
- 日常重复工作自动化

## 目录结构

每个方案位于 `solutions/YYYY-MM-DD-short-topic/`，至少包含：

- `README.md`：完整中文教程
- `PROMPT.md`：可直接复制给 Codex 的提示词
- `TESTING.md`：测试方法和覆盖范围
- `TEST-RESULTS.md`：脱敏后的实际测试结果
- `metadata.json`：分类、难度、风险和验证状态

配套文章位于 `docs/articles/`。方案模板在 `templates/solution/`。

## 本地质量检查

在 PowerShell 中运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-Repository.ps1
```

GitHub Actions 会在推送和拉取请求时重复执行相同检查。

## 许可与安全

代码和文档按 [MIT License](LICENSE) 发布。安全问题请参考 [SECURITY.md](SECURITY.md)，贡献规范请参考 [CONTRIBUTING.md](CONTRIBUTING.md)。
