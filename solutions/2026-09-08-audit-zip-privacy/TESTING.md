# 测试说明

## 测试环境

- Windows PowerShell 5.1
- 使用随机临时目录创建测试 ZIP
- 所有秘密、邮箱和用户名均为运行时拼接的虚构数据
- 测试结束后删除临时目录
- 不访问网络，不读取用户真实文件

## 覆盖范围

| 场景 | 预期结果 |
|---|---|
| 普通文本 ZIP | 返回 `Safe` 和退出码 0 |
| 虚构 API 密钥 | 识别风险但不输出原值 |
| 虚构邮箱和用户路径 | 识别并保持报告脱敏 |
| `.env` 等敏感文件名 | 要求人工复核 |
| 路径穿越条目 | 标记为高风险 |
| 重复扫描 | 输出保持一致 |
| 保存 JSON 报告 | 文件可解析且内容一致 |
| 无效 ZIP | 结构化失败，不产生未处理异常 |
| 超大文本条目 | 明确报告未扫描，不静默忽略 |

## 运行方法

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Run-Tests.ps1
```

随后在仓库根目录运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-Repository.ps1
```
