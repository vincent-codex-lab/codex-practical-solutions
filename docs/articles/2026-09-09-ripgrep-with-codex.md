# 大项目里找一行代码，不必让 Codex 从头翻到尾

今天分享一个朴素但很实用的工具：ripgrep，命令名是 `rg`。它能在本地目录里快速搜索文字或正则表达式，默认尊重 `.gitignore`，并跳过隐藏文件和二进制文件。

它最适合解决一个常见问题：项目文件很多，而你只知道一段报错、一个函数名或一个配置项。让 Codex 先用 `rg` 找到相关文件和行号，再读取上下文、解释原因或修改，范围会清楚很多。

## 三个马上能用的命令

```powershell
rg --files
rg -n "TODO|FIXME" .
rg -n -i "error|exception|failed" .
```

第一个命令列出搜索范围；第二个查待办标记；第三个忽略大小写查常见错误词。没有匹配时退出码 1 通常只是“没找到”，不是工具坏了。

## 安全地交给 Codex

```text
请先在当前项目中用 rg 定位与我的问题相关的文件和行号，不要修改文件。默认尊重 .gitignore，不要搜索项目外目录。不要输出令牌、密码、Cookie、邮箱或个人路径原文；命中敏感内容时只给出路径、行号、风险类型和脱敏摘要。请区分无匹配与命令错误，并说明搜索范围和未验证部分。
```

## 安装和来源

Windows 可使用：

```powershell
winget install BurntSushi.ripgrep.MSVC
```

本次只参考并链接[官方仓库](https://github.com/BurntSushi/ripgrep)与[正式版本 15.2.0](https://github.com/BurntSushi/ripgrep/releases/tag/15.2.0)，没有在本仓库镜像第三方二进制文件。隔离测试实际使用 ripgrep 15.2.0，共 13 项测试通过。

## 需要知道的边界

`rg` 是文字搜索，不理解业务含义；默认跳过的文件可能正好是你要找的内容。它还会把匹配行打印出来，因此搜索秘密时不要把原始输出直接发到公开聊天或 Issue。

完整安装、卸载、隐私说明、替代工具和可复现测试见[方案目录](../../solutions/2026-09-09-ripgrep-with-codex/README.md)。
