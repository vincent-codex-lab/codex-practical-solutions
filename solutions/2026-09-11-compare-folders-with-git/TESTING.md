# 测试说明

## 测试环境

- Windows x64，Windows PowerShell 5.1 与 PowerShell 7.6.5
- Git 2.53.0.windows.3
- 随机临时目录、模拟文本与模拟二进制文件
- 无真实账号、无管理员权限
- 核心比较不访问远程仓库，测试结束后删除临时目录

## 测试范围

| 场景 | 预期结果 |
|---|---|
| 版本检查 | `git --version` 返回实际版本 |
| 新增、修改、删除 | `--name-status` 正确显示 A、M、D |
| 未变化文件 | 不出现在差异清单 |
| 统计模式 | `--stat` 给出变化文件数量 |
| 完全相同目录 | 输出为空，退出码为 0 |
| 存在差异 | 退出码为 1，不误判为程序错误 |
| 普通文本正文 | 指定后能看到行级变化 |
| 二进制文件 | 能识别文件发生变化 |
| 空格与中文文件名 | 使用相对路径正确报告 |
| 无效路径 | 返回非 0 退出码和明确错误文字并停止 |
| 重复运行 | 两次状态输出一致 |
| 只读性 | 比较前后文件数量和 SHA-256 不变 |
| 仓库副作用 | 不创建 `.git` 目录 |
| 外部差异程序 | `--no-ext-diff` 禁止调用外部 helper |
| 网络依赖 | 设置不可用代理后，本地比较结果不变 |
| 清理 | 随机临时目录被删除 |

## 测试命令

在仓库根目录运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\solutions\2026-09-11-compare-folders-with-git\tests\Run-Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-Repository.ps1
```

测试调用 PATH 中已有的 Git，不下载安装程序，不访问用户项目。
