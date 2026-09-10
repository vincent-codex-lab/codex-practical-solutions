# 测试说明

## 测试环境

- Windows x64
- Windows PowerShell 5.1 与 PowerShell 7.6.5
- 随机临时目录和模拟文件
- 无真实账号、无管理员权限、无网络访问
- 测试结束后删除临时目录

## 测试范围

| 场景 | 预期结果 |
|---|---|
| 默认预览 | 报告计划但不修改任何文件 |
| 正常执行 | 根层文件按扩展名进入正确分类 |
| 大小写扩展名 | `.JPG` 仍归入图片 |
| 未知扩展名 | 进入“其他” |
| 同名冲突 | 生成带序号名称，不覆盖已有文件 |
| 子目录 | 不递归、不移动子目录里的文件 |
| 重复运行 | 没有新根层文件时不产生重复移动或空清单 |
| 撤销 | 恢复本次移动的文件和原文件名 |
| 无效路径 | 安全失败，不创建内容 |
| 中途失败 | 移动前已生成清单，解除占用后可撤销已完成部分 |
| 隐私字段 | 清单结构不包含令牌、Cookie、密码等字段 |
| 清理 | 临时测试目录被删除 |

## 测试命令

在仓库根目录运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\solutions\2026-09-10-organize-downloads-safely\tests\Run-Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-Repository.ps1
```

测试只在随机临时目录中创建模拟文件，不访问真实下载目录。
