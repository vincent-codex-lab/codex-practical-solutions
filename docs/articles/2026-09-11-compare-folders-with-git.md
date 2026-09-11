# 两个文件夹哪里不一样？让 Codex 用 Git 做只读对比

收到“旧版”和“新版”两个目录时，逐个打开文件很慢，直接覆盖又可能丢内容。Git 不只用于代码仓库：`git diff --no-index` 可以比较任意两个磁盘路径，不需要先执行 `git init`。

本次分享的是第三方开源工具 Git for Windows 的一个实用用法。先看新增、修改、删除的文件名与数量，再决定是否查看少量文本正文，可以让 Codex 更快定位变化，也减少敏感内容直接出现在聊天中的风险。

## 适合谁

- Windows 普通用户、内容创作者和小团队
- 需要比较项目备份、文档目录或素材清单的用户
- 已安装 Git，或可以从官方来源安装 Git for Windows 的用户

## 准备工作

把两个目录放进同一个父目录，例如“对比区\旧版”和“对比区\新版”。重要资料先做独立备份。运行 `git --version` 确认 Git 可用；没有时从 [Git for Windows 官方主页](https://gitforwindows.org/)或 winget 安装。

## 可直接复制给 Codex 的提示词

```text
请只读比较我指定的旧版和新版文件夹，不创建 Git 仓库，不修改文件。先从共同父目录运行 git diff --no-index，并加上 --no-ext-diff、--no-renames、--no-color。第一遍只用 --name-status，第二遍只用 --stat；只汇总新增、修改、删除的相对文件名和数量，文件名含隐私时先脱敏。退出码 0 表示相同；退出码 1 且输出为正常差异清单时表示发现差异。如果输出包含 error: 或路径不可访问文字，则按命令错误处理。未经我明确指定，不显示任何文件正文。完成后核对文件数量、哈希和 .git 目录，证明比较保持只读。
```

## 操作步骤

```powershell
Set-Location "D:\对比区"
git -c core.quotepath=false diff --no-index --no-ext-diff --no-renames --no-color --name-status -- "旧版" "新版"
git -c core.quotepath=false diff --no-index --no-ext-diff --no-renames --no-color --stat -- "旧版" "新版"
```

`A` 是新版新增，`M` 是内容变化，`D` 是新版删除。存在差异时退出码通常为 `1`；路径错误也可能返回 `1`，所以还要确认输出中没有 `error:` 或无法访问路径的提示。

## 预期结果

Codex 给出脱敏后的变化文件清单和数量，不创建 `.git`，不修改两个目录，也不展示正文。只有用户明确指定一个普通文本文件后，才进一步查看该文件的行级差异。

## 失败处理

- 找不到 Git：重新打开终端并运行 `Get-Command git`；仍不存在则从官方来源安装。
- 路径不存在：核对引号和目录名，不要扩大到整个磁盘。
- 输出太多：保留 `--name-status` 或 `--stat`，不要直接生成完整 diff。
- 命令“返回 1”：正常列出 A、M、D 才表示差异；出现 `error:` 或路径无法访问则按错误处理。

## 隐私与安全提醒

状态模式不会输出正文，但文件名也可能包含客户、姓名或项目隐私。详细 diff 会展示文本内容，可能包括令牌、邮箱和配置，因此不能直接公开粘贴。`--no-ext-diff` 可阻止调用本机配置的外部差异程序。

本次使用 Git 2.53.0.windows.3，在随机临时目录完成隔离测试；核心比较不联网、不需要账号或管理员权限，没有把 Git 二进制重新上传到本仓库。核验时 [Git for Windows 官方主页](https://gitforwindows.org/)显示最新正式版为 2.55.0.windows.5。

## 能力边界

Git 能指出文件或文本行变化，但不能判断哪一版业务内容正确。二进制文件通常只能知道“发生变化”；`--no-renames` 会把改名保守地显示为删除加新增。完整说明、卸载方法和测试证据见[方案目录](../../solutions/2026-09-11-compare-folders-with-git/README.md)。
