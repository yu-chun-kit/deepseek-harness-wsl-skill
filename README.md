# 在 WSL 中运行 DeepSeek Harness — Codex Skill 与安装器

**简体中文** | [繁體中文](README.zh-TW.md) | [English](README.en.md)

这是一个社区维护的 Codex Skill 和可恢复执行的 PowerShell 安装器，用于在 Windows 的 WSL2 中安全安装、更新和检查 DeepSeek 官方的 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)。

它安装的是 npm 官方包 `@deepseek-ai/dsh`，不是分叉版本、模型包装器或名称相似的第三方 Harness。

> [!IMPORTANT]
> 本项目不是 DeepSeek 官方 Skill。DeepSeek Harness 目前仍处于 Developer Preview，未来可能出现破坏兼容性的更新。本项目不声称 DeepSeek-V4-Pro 已被证明“过拟合 Harness”，也不声称 Linux 会让模型本身变得更聪明。

## 为什么使用 WSL？

DeepSeek V4 技术报告披露的 code-agent 评测使用了 Bash 和文件编辑工具。公开 Harness 的 Minimal preset 也采用 persistent Bash 与 `str_replace_editor`。

Harness 同样支持原生 Windows。本项目推荐 WSL2，是为了获得更接近 Linux 的路径、权限、信号、Shell 行为和常见 SWE/terminal 工具；这是兼容性和可复现性选择，不是模型推理加速。

公开 Minimal preset 晚于 V4 技术报告出现。合理的说法是它与报告披露的内部评测形态相似，而不是模型训练时直接使用了今天公开仓库里的 preset。

## 新手先选：原生 Windows 还是 WSL2？

如果电脑已经在使用 WSL2，复用现有 Ubuntu 通常最省事。如果从未安装 WSL，请先明确选择：

| 方案 | 适合谁 | 代价 |
|---|---|---|
| 原生 Windows | 只想使用官方 Harness UI，并希望尽量少改系统的新手 | 使用 PowerShell/Windows 语义，而不是本项目面向的 Bash 环境 |
| WSL2 | 需要 Linux/Bash 工具兼容性，希望更接近已披露评测环境的用户 | 会新增 Ubuntu、Linux 账号、虚拟磁盘，并可能需要管理员权限和重启 |

原生 Windows 路径请按照官方 README：安装受支持的 Windows Node.js，然后在 PowerShell 中运行 `npx @deepseek-ai/dsh web`。本 Skill 只自动化 WSL 路径，不声称 WSL 是必需的。

Microsoft 当前公布的 WSL2 默认 VM 上限为：Windows 总内存的 50%、全部逻辑处理器，以及 Windows 内存 25%（向上取到最接近的 GB）的 swap。这些是上限，并非 Windows 开机时立即预占。WSL 在被命令或依赖应用调用时启动，之后由 WSL 管理 VM 生命周期。

DeepSeek 没有公布 Harness 的最低 RAM、每个 session 的 RAM 或多会话计算公式，因此本项目不会把 `memory=2GB` 标为推荐值。官方工程笔记曾测得 50 个 standard agents 约占 57.8 MB；另一项 130 万事件大型 session 恢复测试的优化后峰值 RSS 约为 1,060 MiB。两者都是特定实现测量，不是系统要求，也不包括 agent 启动的编译、测试和语言服务器等工作负载。

> [!CAUTION]
> `%USERPROFILE%\.wslconfig` 会影响所有 WSL2 发行版，包括 Docker Desktop 和其他 Linux 工作。本项目只报告该文件是否存在，绝不会自动读取内容、创建、合并或覆盖它，也不会自动套用 2GB 上限。

## 快速开始

克隆或下载本仓库，在仓库根目录打开 PowerShell，先检查当前状态：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deepseek-harness-wsl\scripts\setup-deepseek-harness-wsl.ps1 -Action status
```

预览将要发生的改动：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deepseek-harness-wsl\scripts\setup-deepseek-harness-wsl.ps1 -Action install -AcceptPrerelease -WhatIf
```

安装或继续之前中断的安装：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deepseek-harness-wsl\scripts\setup-deepseek-harness-wsl.ps1 -Action install -AcceptPrerelease -Yes
```

如果状态检查显示尚未安装 WSL，并且你明确选择 WSL2 路径，先预览平台安装：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deepseek-harness-wsl\scripts\setup-deepseek-harness-wsl.ps1 -Action install -InstallWslIfMissing:$true -AcceptPrerelease -WhatIf
```

确认后，在管理员 PowerShell 中把 `-WhatIf` 换成 `-Yes` 再运行。只有首次新增 WSL/Ubuntu 时需要显式提供 `-InstallWslIfMissing:$true`。

Windows Node.js 与 WSL Linux Node.js 是两个独立安装。选择 WSL 后，如果 Linux 内没有兼容 Node，本安装器会在 Linux 用户目录中安装当前 Node.js LTS，绝不会使用 `/mnt/c` 下的 `node.exe`。当前官方源码开发支持范围为 Node.js 22.19+ 或 24+；发布的 CLI 包目前没有单独声明 `engines`，因此安装器采用官方源码范围作为保守下限。

默认 `-PackageManager auto` 会沿用之前受管理安装所记录的管理器。新安装只有在现有 Linux 原生 pnpm 的全局目录可写时才使用 pnpm，否则使用 npm。官方对发布包的运行方式是 npm/npx；`pnpm install`、`pnpm run build` 和 `pnpm dsh web` 属于源码 checkout 流程。

如果 npm 的官方 `latest` 仍指向 RC，必须显式使用 `-AcceptPrerelease`。当 `latest` 变为稳定版后可移除此参数。

### 首次安装可能跨越重启

默认命令在没有 WSL 时只显示主机 RAM、CPU、系统盘空间与两种平台选择。只有显式 opt-in 才会进入官方 `wsl --install` 流程。

安装器不会自行提升权限或重启电脑。Windows 要求重启时，请手动重启；Ubuntu 首次启动要求创建 Linux 用户名和密码时，请在本机完成，然后重新运行同一条命令。

如果已有或导入的发行版直接以 `root` 启动，而且从不显示首次设置界面，安装器会在修改前停止。经用户明确确认后，可按以下形态恢复：

```powershell
$distro = 'Ubuntu-24.04' # 替换为已核对的发行版名称
$linuxUser = 'alice'     # 替换为用户选择的新 Linux 账号
wsl.exe -d $distro -u root -- adduser $linuxUser
wsl.exe -d $distro -u root -- usermod -aG sudo $linuxUser
wsl.exe --manage $distro --set-default-user $linuxUser
wsl.exe -d $distro -- id
```

执行前必须检查两个变量。安装器不会猜用户名、替用户输入密码，也不会自动替换 `/etc/wsl.conf`。

## 运行 Harness

在 WSL 终端进入允许 Harness 操作的项目目录，然后启动 Web UI：

```bash
cd ~/projects/your-project
dsh web
```

打开 <http://127.0.0.1:3080>，进入 **Settings → Models**，在页面中输入 DeepSeek API key。不要把 key 粘贴到 agent 对话、命令行、仓库、`.env` 或 shell history 中。

Linux 工具密集型项目建议放在 `~/projects` 等 WSL Linux 文件系统内，而不是 `/mnt/c` 或 `/mnt/e`。Windows 挂载盘可以互通，但 Git/npm I/O 和 Linux 权限语义通常不如 WSL ext4。

## 安装 Codex Skill

将 `deepseek-harness-wsl` 目录复制到个人 Codex skills 目录；如果目标已存在，不要未经检查直接覆盖：

```powershell
$destination = Join-Path $env:USERPROFILE '.codex\skills\deepseek-harness-wsl'
if (Test-Path -LiteralPath $destination) { throw "Skill already exists: $destination" }
Copy-Item -LiteralPath .\deepseek-harness-wsl -Destination $destination -Recurse
```

然后可以对 Codex 说：

```text
使用 $deepseek-harness-wsl 检查我的 Windows/WSL 环境，并在 WSL2 中安装官方 DeepSeek Harness。
```

## Minimal 极简模式

启动 `dsh web`，创建 session 时选择 **极简模式 / Minimal**。它是 Web UI 中的 agent preset，不是 `dsh minimal` CLI 子命令。

Minimal 中表现更好可能来自训练/评测分布匹配、工具协议、reasoning trace、上下文策略或 Shell 差异。没有受控的跨 Harness 消融实验，就不能把“过拟合”写成已证实事实。

## 实验性 Anchored 模式

后续社区实验发现，影响可能不只是一句 system prompt，而是**第一次请求**同时看到的 persona、工具目录、输出上限和自动注入上下文。一个 Anchored Standard 实验让首轮只看到 Bash/`read`，首个工具调用或回复后再恢复完整 Standard 工具；它在一个私有冻结任务的两次运行中得到 98/99。这是有价值的线索，但仍不是通用基准，也不能证明 DeepSeek 存在训练 bug。

本项目因此提供可选脚本，为当前已安装的官方 preset 生成独立副本：

- `Anchored Standard`：有上述单任务、两次运行的社区证据；
- `Anchored PTC / Code`：同一机制的未验证外推；
- `Anchored Cordis / Creator`：诊断用途外推，而且会失去 Cordis 原本的专用 system persona，不建议作为日常默认。

它不是 prompt 模板，因为普通 prompt 无法改变 API 可见工具 schema、首轮 `max_tokens` 或 Harness 自动注入内容。脚本不会修改官方 preset 或 `node_modules`；Harness 更新后可以从新版本重新生成。

```powershell
# 先检查与预览；多发行版时必须写明 -Distribution
powershell -NoProfile -ExecutionPolicy Bypass -File .\deepseek-harness-wsl\scripts\manage-anchored-presets.ps1 -Action status -Distribution Ubuntu -Mode all
powershell -NoProfile -ExecutionPolicy Bypass -File .\deepseek-harness-wsl\scripts\manage-anchored-presets.ps1 -Action install -Distribution Ubuntu -Mode all -WhatIf

# 接受实验边界后安装
powershell -NoProfile -ExecutionPolicy Bypass -File .\deepseek-harness-wsl\scripts\manage-anchored-presets.ps1 -Action install -Distribution Ubuntu -Mode all -Yes
```

完全重启 `dsh web`，新建空白 session 后再选择 anchored preset；不要把已有 session 切换过去。完整原理、证据等级、更新与卸载边界见 [anchored-presets.md](deepseek-harness-wsl/references/anchored-presets.md)。

## 安全更新与回滚

通过同一入口更新：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deepseek-harness-wsl\scripts\setup-deepseek-harness-wsl.ps1 -Action update -AcceptPrerelease -Yes
```

安装器不会盲目运行 `npx @latest`。它会查询官方 npm registry、把 channel 解析为精确版本、显示 repository 与 integrity、确认仓库指向 `deepseek-ai/deepseek-harness`，然后安装该精确版本并记录前后版本。

回滚到已知版本：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deepseek-harness-wsl\scripts\setup-deepseek-harness-wsl.ps1 -Action install -PackageVersion 0.1.0-rc.6 -AcceptPrerelease -Yes
```

## 主要参数

| 参数 | 用途 |
|---|---|
| `-Action status` | 只检查，不安装 |
| `-Action install` | 安装或继续安装 |
| `-Action update` | 解析并安装所选 channel 的当前精确版本 |
| `-Action uninstall` | 只移除 Harness，保留 Node、数据、发行版和 WSL |
| `-Distribution <name>` | 使用明确指定的已安装发行版 |
| `-Channel latest\|next` | 选择 npm dist-tag |
| `-PackageManager auto\|npm\|pnpm` | 沿用记录的管理器，或选择现有可用 pnpm/npm |
| `-PackageVersion <semver>` | 安装指定精确版本 |
| `-FetchRetries 0..10` | 本次运行的下载重试次数，默认 4 |
| `-FetchTimeoutSeconds 30..900` | 本次运行的单请求超时，默认 300 秒 |
| `-NetworkConcurrency 1..50` | registry 并发连接数，默认 15 |
| `-DownloadAttempts 1..3` | 同一精确版本的安装尝试次数，默认 2 |
| `-NativeBuildTools auto\|skip` | 检查 Ubuntu 原生编译依赖，或明确跳过 |
| `-AcceptPrerelease` | 明确允许 RC/beta |
| `-Yes` | 接受显示的包与 prerequisite 改动 |
| `-WhatIf` | 预览改动；metadata 检查仍可能联网 |
| `-SkipNodeInstall` | 缺少兼容 Linux Node 时直接失败 |
| `-InstallWslIfMissing:$true` | 明确允许新增 WSL/Ubuntu；默认 false |

## 安装器会修改什么？

根据当前状态，它可能：

- 通过官方 `wsl --install` 新增 Ubuntu 24.04；
- 安装缺少的 `git`、`curl`、CA certificates、`build-essential` 和 Python 3；
- 使用固定 nvm tag，并核对 commit 后安装当前 Node.js LTS；
- 备份 `~/.profile`，再添加带 marker 的最小 nvm 或 npm prefix/PATH 区块；
- 当 `/usr` 不可写时使用用户目录 `~/.local`，绝不使用 `sudo npm -g`；
- 通过 npm 或已存在的 Linux pnpm 安装精确版本 `@deepseek-ai/dsh`；
- 在 `~/.local/state/deepseek-harness-wsl/` 写入不含 secret 的版本与回滚记录。

它不会修改默认发行版、转换 WSL1、编辑 `.wslconfig`、VPN、DNS、防火墙或代理，不会公开监听 Web UI、保存 API key、删除工作区或注销发行版。

## 常见问题

### Windows 变慢或 `vmmem` 很大

先检查 `wsl --list --running`，以及 Harness、Docker、测试或其他 Linux 工作是否仍在运行。关闭浏览器标签不一定会终止 Harness server 或子进程。

不要直接粘贴通用 `memory=2GB` 配置。该上限会影响所有 WSL2 发行版，也没有与会话数量对应的 DeepSeek 官方公式。`wsl --shutdown` 会终止所有运行中的发行版，因此本项目不会自动执行它。

WSL2 使用动态扩展虚拟磁盘。删除 Linux 文件会降低 guest 文件系统用量，但不保证 host 上的 VHD 文件立即缩小。请遵循 Microsoft 当前磁盘管理指南，不要直接删除或编辑 `ext4.vhdx`。

### npm 无权写入 `/usr/lib/node_modules`

系统 Node 可能可用，但 npm global prefix `/usr` 对普通用户不可写。重新运行本 Skill；它会选择 `~/.local` 并持久化受管理 PATH。不要使用 `sudo npm install --global`、递归修改 `/usr` 所有权或自动删除疑似残留目录。

### registry metadata 正常，但某个 `.tgz` 超时

metadata 和 tarball 是不同 HTTP 请求。安装器只对已验证的同一精确版本做有界重试，并保持官方 registry、TLS 与 integrity 检查。不要使用非官方镜像、`strict-ssl=false`、`curl -k` 或 `npm cache clean --force`；切换 pnpm 也不能保证改变网络路由。

较慢网络可显式降低并发并增加有限等待：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deepseek-harness-wsl\scripts\setup-deepseek-harness-wsl.ps1 -Action install -FetchRetries 6 -FetchTimeoutSeconds 600 -NetworkConcurrency 4 -DownloadAttempts 3 -AcceptPrerelease -Yes
```

### `node-pty` 或 node-gyp 编译失败

默认 `-NativeBuildTools auto` 会检查 `make`、Python 3、GCC 和 G++。Ubuntu 缺件时只刷新 apt index 并安装必要包，不执行完整 `apt upgrade`。如果 agent 无法交互输入 sudo 密码，安装器会停止并打印用户可在 WSL 终端执行的恢复命令，不会偷偷改用 root。

### `dsh` 已安装但命令找不到

Windows 发起的非 login WSL 命令不一定读取 `~/.profile`。状态检查会直接解析并验证受管理的 `dsh` 绝对路径，不会 source 任意用户 profile，也不会通过向 `.bashrc`、`.npmrc` 重复写设置来掩盖问题。

## 卸载

只移除 Harness：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deepseek-harness-wsl\scripts\setup-deepseek-harness-wsl.ps1 -Action uninstall -Yes
```

移除 Node.js、用户设置、WSL 发行版或 WSL 本身属于独立高风险操作，不在此命令范围内。

## 主要来源

- [DeepSeek Harness 官方仓库](https://github.com/deepseek-ai/deepseek-harness)
- [DeepSeek Harness 源码开发要求](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/development.md)
- [DeepSeek Windows PowerShell 支持说明](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/feature/2026-08-01-windows-pwsh-default.md)
- [DeepSeek per-session agent 测量](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/architecture/2026-08-03-per-session-agent-presets.md)
- [DeepSeek 大型 session 恢复测量](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/architecture/2026-08-05-large-session-jsonl-restore-pipeline.md)
- [DeepSeek V4 技术报告](https://arxiv.org/html/2606.19348v1)
- [Microsoft：安装 WSL](https://learn.microsoft.com/windows/wsl/install)
- [Microsoft：WSL 高级设置](https://learn.microsoft.com/windows/wsl/wsl-config)
- [Microsoft：管理 WSL 磁盘空间](https://learn.microsoft.com/windows/wsl/disk-space)
- [Microsoft：WSL 基本命令](https://learn.microsoft.com/windows/wsl/basic-commands)
- [npm install 文档](https://docs.npmjs.com/cli/commands/npm-install/)
- [pnpm request 设置](https://pnpm.io/settings#request-settings)
- [node-pty Linux 构建依赖](https://github.com/microsoft/node-pty#dependencies)
- [node-gyp Unix prerequisites](https://github.com/nodejs/node-gyp#on-unix)

## License

[MIT](LICENSE)
