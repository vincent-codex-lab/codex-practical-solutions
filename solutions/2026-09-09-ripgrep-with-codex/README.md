# 用 ripgrep 帮 Codex 快速定位大项目里的代码

## 今天解决什么问题

项目文件一多，逐个打开文件找报错、配置或函数会很慢。ripgrep（命令名 `rg`）能在本地快速搜索文件内容；先让 Codex 用它缩小范围，再分析和修改，通常更准确也更容易复核。

本方案只分享使用方法和测试，不打包、不镜像第三方程序。ripgrep 不是 OpenAI 产品，也不是 Codex 专用插件。

## 适合谁

- Windows 用户，以及需要在代码仓库或文本目录中查找内容的人
- 已安装 Codex、PowerShell，并能在终端运行命令的人
- 想减少 Codex 无目的遍历文件、先定位再处理的人

不适合把它当语义搜索、杀毒工具或秘密扫描器；它只按文字或正则表达式匹配。

## 来源与本次核验

- 官方仓库：[BurntSushi/ripgrep](https://github.com/BurntSushi/ripgrep)
- 官方说明：[README](https://github.com/BurntSushi/ripgrep/blob/master/README.md)
- 本次核验的最新正式版本：[15.2.0](https://github.com/BurntSushi/ripgrep/releases/tag/15.2.0)，发布于 2026-07-15
- 官方仓库未归档，核验时仍有后续提交
- 官方仓库说明采用 MIT 或 Unlicense 双重许可
- 本机实际测试版本：ripgrep 15.2.0，Windows x64，带 PCRE2

版本和维护状态会变化，安装前应再次查看官方 Releases，不要从不明下载站获取程序。

## 安装方法

### 方法一：Windows Package Manager

```powershell
winget install BurntSushi.ripgrep.MSVC
```

安装后关闭并重新打开终端，再验证：

```powershell
rg --version
```

### 方法二：便携版

从官方 Release 下载与系统匹配的 Windows ZIP，同时下载对应 `.sha256` 文件并核对哈希。解压到单独目录，将该目录加入 PATH，或者用 `rg.exe` 的完整路径运行。不要把来源不明的 `rg.exe` 放进项目。

## 先自己试三个命令

在项目根目录运行：

```powershell
rg --files
rg -n "TODO|FIXME" .
rg -n -i "error|exception|failed" .
```

- `--files`：列出它会搜索的文件。
- `-n`：显示行号。
- `-i`：忽略大小写。
- 默认会遵守 `.gitignore`，并跳过隐藏文件和二进制文件。

需要搜索隐藏文件时可以显式使用：

```powershell
rg -n --hidden --glob '!.git/**' "关键词" .
```

不要随意加 `--no-ignore` 后把大量依赖、缓存或秘密文件的内容贴到聊天中。

## 和 Codex 一起使用

复制 [PROMPT.md](PROMPT.md) 中的提示词，把“目标”换成自己的问题。合理流程是：

1. 用 `rg --files` 了解范围。
2. 用具体关键词或正则缩小到少量文件和行号。
3. 只读取相关上下文，解释证据。
4. 在你明确要求修改后才编辑，并运行项目原有测试。

## 预期结果

Codex 应先报告命中的文件、行号和必要的脱敏摘要，再说明下一步。没有匹配时，`rg` 通常返回退出码 1，这表示“未找到”，不等于程序损坏。

## 失败时如何处理

- 提示找不到 `rg`：重新开终端；仍失败则运行 `Get-Command rg`，检查是否安装或 PATH 是否生效。
- 搜不到已知内容：确认大小写、文件是否被 `.gitignore` 忽略、是否为隐藏文件或二进制文件。
- 正则报错：先用 `rg -F "原样文字" .` 做固定字符串搜索。
- 输出太多：增加目录、文件类型或 `--glob` 限制，不要直接扩大到整个磁盘。
- 版本异常：卸载非官方来源版本，改用官方 Release 或 winget 包。

## 卸载

winget 安装可运行：

```powershell
winget uninstall BurntSushi.ripgrep.MSVC
```

便携版可在确认目录里没有自己的文件后，删除单独的解压目录，并从 PATH 移除该目录。

## 隐私、网络与权限

核心搜索读取本地文件，不需要账号、API Key 或管理员权限，本次隔离测试也不需要网络。安装和检查新版本需要联网。`rg` 会把匹配内容打印到终端，因此搜索令牌、密码、Cookie、个人路径时可能在输出或聊天记录中造成二次泄露；让 Codex只报告路径、行号和脱敏摘要。

测试没有使用真实账号、真实项目或私人数据，也没有复制第三方二进制文件到仓库。

## 能力边界与替代工具

- ripgrep 不理解业务含义，关键词选错就可能漏掉结果。
- 默认跳过隐藏、忽略和二进制文件，这是安全且高效的默认值，但也可能漏掉目标。
- 搜索结果只是线索，不能替代阅读上下文、运行测试和人工确认。
- 小目录可以用 PowerShell `Select-String`；Git 已跟踪文件可用 `git grep`；图形界面用户可用 VS Code 全局搜索。

可复现测试见 [TESTING.md](TESTING.md)，实际结果见 [TEST-RESULTS.md](TEST-RESULTS.md)。
