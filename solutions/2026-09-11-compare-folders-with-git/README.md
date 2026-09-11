# 不用建立仓库，用 Git 和 Codex 安全比较两个文件夹

## 今天解决什么问题

收到“旧版”和“新版”两个文件夹时，常常不知道哪些文件新增、修改或删除。Git 的 `git diff --no-index` 可以直接比较磁盘上的两个路径，不要求它们是 Git 仓库。先让 Codex只看文件状态和统计，再按需查看少量文本差异，可以避免手工逐个打开。

本方案分享第三方工具 Git for Windows 的一个只读用法，不打包或镜像 Git，也不代表 Git 项目或 OpenAI 对本仓库提供背书。

## 适合谁

- 想比较项目、文档或素材目录两个版本的 Windows 用户
- 收到供应商、同事或备份目录，需要先核对差异的小团队
- 已有 Git，或能从官方来源安装 Git for Windows 的用户

它适合比较文件级差异，不适合判断哪一版业务内容更正确，也不能代替备份。

## 来源与本次核验

- 官方主页：[Git for Windows](https://gitforwindows.org/)
- 官方命令文档：[git diff](https://git-scm.com/docs/git-diff)
- 核验时官方主页显示的最新正式版：`2.55.0.windows.5`
- 本机实际测试版本：`2.53.0.windows.3`
- 许可证：GPL-2.0
- 本仓库未包含 Git 安装包、可执行文件或源代码

版本会变化；安装时只使用官方主页、官方 GitHub Release 或可信系统包管理器。

## 安装与检查

先检查当前终端是否已有 Git：

```powershell
git --version
```

Windows 没有 Git 时，可以使用：

```powershell
winget install --exact --id Git.Git
```

安装后重新打开终端，再运行 `git --version`。也可以从[官方主页](https://gitforwindows.org/)下载。不要从不明下载站获取修改版安装程序。

## 第一步：准备安全的目录结构

建议把两个待比较目录放在同一个父目录下，例如：

```text
对比区/
├─ 旧版/
└─ 新版/
```

在父目录运行命令并使用相对目录名，这样输出不会带出完整个人路径。

## 第二步：只看哪些文件变化

```powershell
Set-Location "D:\对比区"
git -c core.quotepath=false diff --no-index --no-ext-diff --no-renames --no-color --name-status -- "旧版" "新版"
```

常见状态：`A` 表示新版新增，`M` 表示内容变化，`D` 表示新版删除。第一遍不输出文本内容，但文件名本身仍可能包含隐私。

## 第三步：只看数量统计

```powershell
git -c core.quotepath=false diff --no-index --no-ext-diff --no-renames --no-color --stat -- "旧版" "新版"
```

`--no-ext-diff` 禁止调用外部差异程序，`--no-renames` 避免自动猜测重命名，`--no-color` 让结果便于保存和复核。

两个目录存在差异时，命令退出码通常是 `1`。这是 `--no-index` 的正常语义，不表示 Git 损坏；退出码 `0` 才表示没有差异。但路径不存在等错误也可能返回 `1`，因此必须同时检查输出中是否出现 `error:` 或“无法访问路径”等错误文字。

## 第四步：确有需要再看正文

详细差异可能暴露密码、令牌、邮箱、客户资料或其他内容。只在确认文件不敏感后，对指定文件运行：

```powershell
git -c core.quotepath=false diff --no-index --no-ext-diff --no-renames --no-color -- "旧版\说明.txt" "新版\说明.txt"
```

不要把整个项目的完整 diff 直接粘贴到公开聊天、Issue 或论坛。

## 和 Codex 一起使用

复制 [PROMPT.md](PROMPT.md) 的提示词并填写两个目录。Codex 应先输出脱敏后的文件状态与统计，区分“有差异”和真正的命令错误；只有你明确要求后才读取某个普通文本文件的详细差异。

## 预期结果

- 不需要 `git init`，也不会创建 `.git` 目录。
- 可以得到新增、修改、删除文件列表和统计。
- 比较前后两个目录的文件内容和数量保持不变。
- 完全相同的目录返回退出码 `0`；存在差异返回退出码 `1`。

## 失败时如何处理

- “git 不是命令”：重新打开终端；仍失败则检查 `Get-Command git`，必要时从官方来源安装。
- 路径不存在：停止并核对引号、父目录和目录名，不要改为扫描整个磁盘。
- 输出太多：先保留 `--name-status` 或 `--stat`，不要立即查看完整正文差异。
- 中文显示异常：使用 Windows Terminal 或 PowerShell 7，并保持文件名编码一致。
- 看到退出码 `1`：同时检查输出。正常差异清单表示“发现差异”；出现 `error:` 或无法访问路径则是真正错误。

## 卸载与清理

如果 Git 是专门通过 winget 安装且确认没有其他项目依赖，可运行：

```powershell
winget uninstall --exact --id Git.Git
```

不要删除 Codex、开发工具或其他应用自带的 Git 运行时。本文命令不创建缓存、报告或 `.git` 目录，因此比较完成后没有额外数据需要清理。

## 隐私、网络与权限

本次核心测试在随机临时目录完成，不需要账号、管理员权限或网络。`git diff --no-index` 读取指定路径的文件以计算差异，但使用 `--name-status` 和 `--stat` 时不显示正文。安装和检查新版需要联网。

文件名、目录名和详细 diff 都可能泄露隐私；让 Codex 汇报前应使用相对路径并脱敏。命令加上 `--no-ext-diff`，避免本机配置调用未审查的外部差异程序。

## 能力边界与替代方案

- Git 按字节和文本行比较，不理解合同、图片或视频的业务含义。
- 二进制文件可以识别为变化，但通常不能解释内部差异。
- `--no-renames` 会把重命名显示成一删一增，结论更保守但需要人工判断。
- 它不会同步、合并、复制或备份文件。
- 只比较 Windows 文件清单可使用 `Compare-Object`；需要图形界面可考虑 WinMerge，但应另行核验官方来源与隐私边界。

可复现测试见 [TESTING.md](TESTING.md)，实际结果见 [TEST-RESULTS.md](TEST-RESULTS.md)。
