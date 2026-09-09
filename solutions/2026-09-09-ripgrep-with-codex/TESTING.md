# 测试说明

## 测试环境

- Windows x64
- PowerShell 7
- ripgrep 15.2.0，PCRE2 可用
- 随机临时目录、模拟文本、无真实账号、无管理员权限
- 测试完成后删除临时目录

## 测试范围

| 场景 | 预期结果 |
|---|---|
| 版本检查 | `rg --version` 成功并包含 ripgrep |
| 普通文字与正则 | 找到正确文件和内容 |
| 忽略大小写 | 能找到大小写不同的文字 |
| `.gitignore` | 默认文件列表排除忽略目录 |
| 隐藏文件 | 默认跳过，显式 `--hidden` 时找到 |
| 二进制文件 | 默认不把含 NUL 的模拟二进制作为普通文本输出 |
| JSON 输出 | 每行均可解析，包含匹配事件 |
| 带空格文件名 | 正确报告路径 |
| 无匹配 | 返回退出码 1，而非误判为程序错误 |
| 重复运行 | 两次输出一致 |
| 只读性 | 搜索前后样本文件哈希一致 |

## 测试命令

在仓库根目录运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\solutions\2026-09-09-ripgrep-with-codex\tests\Run-Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-Repository.ps1
```

测试脚本只调用 PATH 中现有的 `rg`，不会下载安装程序或访问真实项目。
