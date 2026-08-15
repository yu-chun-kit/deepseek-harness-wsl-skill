# 在 WSL 中執行 DeepSeek Harness — Codex Skill 與安裝器

[简体中文](README.md) | **繁體中文** | [English](README.en.md)

這是一個社群維護的 Codex Skill 和可恢復執行的 PowerShell 安裝器，用於在 Windows 的 WSL2 中安全安裝、更新和檢查 DeepSeek 官方的 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)。

它安裝的是 npm 官方包 `@deepseek-ai/dsh`，不是分叉版本、模型包裝器或名稱相似的第三方 Harness。

> [!IMPORTANT]
> 本專案不是 DeepSeek 官方 Skill。DeepSeek Harness 目前仍處於 Developer Preview，未來可能出現破壞相容性的更新。本專案不聲稱 DeepSeek-V4-Pro 已被證明“過擬合 Harness”，也不聲稱 Linux 會讓模型本身變得更聰明。

## 為什麼使用 WSL？

DeepSeek V4 技術報告披露的 code-agent 評測使用了 Bash 和檔案編輯工具。公開 Harness 的 Minimal preset 也採用 persistent Bash 與 `str_replace_editor`。

Harness 同樣支援原生 Windows。本專案推薦 WSL2，是為了獲得更接近 Linux 的路徑、權限、訊號、Shell 行為和常見 SWE/terminal 工具；這是相容性和可復現性選擇，不是模型推理加速。

公開 Minimal preset 晚於 V4 技術報告出現。合理的說法是它與報告披露的內部評測形態相似，而不是模型訓練時直接使用了今天公開儲存庫裡的 preset。

## 新手先選：原生 Windows 還是 WSL2？

如果電腦已經在使用 WSL2，複用現有 Ubuntu 通常最省事。如果從未安裝 WSL，請先明確選擇：

| 方案 | 適合誰 | 代價 |
|---|---|---|
| 原生 Windows | 只想使用官方 Harness UI，並希望儘量少改系統的新手 | 使用 PowerShell/Windows 語義，而不是本專案面向的 Bash 環境 |
| WSL2 | 需要 Linux/Bash 工具相容性，希望更接近已披露評測環境的使用者 | 會新增 Ubuntu、Linux 帳號、虛擬磁碟，並可能需要管理員權限和重啟 |

原生 Windows 路徑請按照官方 README：安裝受支援的 Windows Node.js，然後在 PowerShell 中執行 `npx @deepseek-ai/dsh web`。本 Skill 只自動化 WSL 路徑，不聲稱 WSL 是必需的。

Microsoft 當前公佈的 WSL2 預設 VM 上限為：Windows 總記憶體的 50%、全部邏輯處理器，以及 Windows 記憶體 25%（向上取到最接近的 GB）的 swap。這些是上限，並非 Windows 開機時立即預佔。WSL 在被命令或依賴應用呼叫時啟動，之後由 WSL 管理 VM 生命週期。

DeepSeek 沒有公佈 Harness 的最低 RAM、每個 session 的 RAM 或多會話計算公式，因此本專案不會把 `memory=2GB` 標為推薦值。官方工程筆記曾測得 50 個 standard agents 約佔 57.8 MB；另一項 130 萬事件大型 session 恢復測試的最佳化後峰值 RSS 約為 1,060 MiB。兩者都是特定實現測量，不是系統要求，也不包括 agent 啟動的編譯、測試和語言伺服器等工作負載。

> [!CAUTION]
> `%USERPROFILE%\.wslconfig` 會影響所有 WSL2 發行版，包括 Docker Desktop 和其他 Linux 工作。本專案只報告該檔案是否存在，絕不會自動讀取內容、建立、合併或覆蓋它，也不會自動套用 2GB 上限。

## 快速開始

複製或下載本儲存庫，在儲存庫根目錄開啟 PowerShell，先檢查目前狀態：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deepseek-harness-wsl\scripts\setup-deepseek-harness-wsl.ps1 -Action status
```

預覽將要發生的改動：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deepseek-harness-wsl\scripts\setup-deepseek-harness-wsl.ps1 -Action install -AcceptPrerelease -WhatIf
```

安裝或繼續之前中斷的安裝：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deepseek-harness-wsl\scripts\setup-deepseek-harness-wsl.ps1 -Action install -AcceptPrerelease -Yes
```

如果狀態檢查顯示尚未安裝 WSL，並且你明確選擇 WSL2 路徑，先預覽平臺安裝：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deepseek-harness-wsl\scripts\setup-deepseek-harness-wsl.ps1 -Action install -InstallWslIfMissing:$true -AcceptPrerelease -WhatIf
```

確認後，在管理員 PowerShell 中把 `-WhatIf` 換成 `-Yes` 再執行。只有首次新增 WSL/Ubuntu 時需要明確提供 `-InstallWslIfMissing:$true`。

Windows Node.js 與 WSL Linux Node.js 是兩個獨立安裝。選擇 WSL 後，如果 Linux 內沒有相容 Node，本安裝器會在 Linux 使用者目錄中安裝當前 Node.js LTS，絕不會使用 `/mnt/c` 下的 `node.exe`。當前官方原始碼開發支援範圍為 Node.js 22.19+ 或 24+；釋出的 CLI 包目前沒有單獨宣告 `engines`，因此安裝器採用官方原始碼範圍作為保守下限。

預設 `-PackageManager auto` 會沿用之前受管理安裝所記錄的管理器。新安裝只有在現有 Linux 原生 pnpm 的全域目錄可寫時才使用 pnpm，否則使用 npm。官方對發佈套件的執行方式是 npm/npx；`pnpm install`、`pnpm run build` 和 `pnpm dsh web` 屬於原始碼 checkout 流程。

如果 npm 的官方 `latest` 仍指向 RC，必須顯式使用 `-AcceptPrerelease`。當 `latest` 變為穩定版後可移除此引數。

### 首次安裝可能跨越重啟

預設命令在沒有 WSL 時只顯示主機 RAM、CPU、系統磁碟空間與兩種平台選擇。只有明確 opt-in 才會進入官方 `wsl --install` 流程。

安裝器不會自行提升權限或重啟電腦。Windows 要求重啟時，請手動重啟；Ubuntu 首次啟動要求建立 Linux 使用者名稱和密碼時，請在本機完成，然後重新執行同一條命令。

如果已有或匯入的發行版直接以 `root` 啟動，而且從不顯示首次設定介面，安裝器會在修改前停止。經使用者明確確認後，可按以下形態恢復：

```powershell
$distro = 'Ubuntu-24.04' # 替換為已核對的發行版名稱
$linuxUser = 'alice'     # 替換為使用者選擇的新 Linux 帳號
wsl.exe -d $distro -u root -- adduser $linuxUser
wsl.exe -d $distro -u root -- usermod -aG sudo $linuxUser
wsl.exe --manage $distro --set-default-user $linuxUser
wsl.exe -d $distro -- id
```

執行前必須檢查兩個變數。安裝器不會猜使用者名稱、替使用者輸入密碼，也不會自動替換 `/etc/wsl.conf`。

## 執行 Harness

在 WSL 終端進入允許 Harness 操作的專案目錄，然後啟動 Web UI：

```bash
cd ~/projects/your-project
dsh web
```

開啟 <http://127.0.0.1:3080>，進入 **Settings → Models**，在頁面中輸入 DeepSeek API key。不要把 key 貼到 agent 對話、命令列、儲存庫、`.env` 或 shell history 中。

Linux 工具密集型專案建議放在 `~/projects` 等 WSL Linux 檔案系統內，而不是 `/mnt/c` 或 `/mnt/e`。Windows 掛載磁碟可以互通，但 Git/npm I/O 和 Linux 權限語義通常不如 WSL ext4。

## 安裝 Codex Skill

將 `deepseek-harness-wsl` 目錄複製到個人 Codex skills 目錄；如果目標已存在，不要未經檢查直接覆蓋：

```powershell
$destination = Join-Path $env:USERPROFILE '.codex\skills\deepseek-harness-wsl'
if (Test-Path -LiteralPath $destination) { throw "Skill already exists: $destination" }
Copy-Item -LiteralPath .\deepseek-harness-wsl -Destination $destination -Recurse
```

然後可以對 Codex 說：

```text
使用 $deepseek-harness-wsl 檢查我的 Windows/WSL 環境，並在 WSL2 中安裝官方 DeepSeek Harness。
```

## Minimal 極簡模式

啟動 `dsh web`，建立 session 時選擇 **極簡模式 / Minimal**。它是 Web UI 中的 agent preset，不是 `dsh minimal` CLI 子命令。

Minimal 中表現更好可能來自訓練/評測分佈匹配、工具協議、reasoning trace、上下文策略或 Shell 差異。沒有受控的跨 Harness 消融實驗，就不能把“過擬合”寫成已證實事實。

## 安全更新與回滾

透過同一入口更新：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deepseek-harness-wsl\scripts\setup-deepseek-harness-wsl.ps1 -Action update -AcceptPrerelease -Yes
```

安裝器不會盲目執行 `npx @latest`。它會查詢官方 npm registry、把 channel 解析為精確版本、顯示 repository 與 integrity、確認儲存庫指向 `deepseek-ai/deepseek-harness`，然後安裝該精確版本並記錄前後版本。

回滾到已知版本：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deepseek-harness-wsl\scripts\setup-deepseek-harness-wsl.ps1 -Action install -PackageVersion 0.1.0-rc.6 -AcceptPrerelease -Yes
```

## 主要引數

| 引數 | 用途 |
|---|---|
| `-Action status` | 只檢查，不安裝 |
| `-Action install` | 安裝或繼續安裝 |
| `-Action update` | 解析並安裝所選 channel 的當前精確版本 |
| `-Action uninstall` | 只移除 Harness，保留 Node、資料、發行版和 WSL |
| `-Distribution <name>` | 使用明確指定的已安裝發行版 |
| `-Channel latest\|next` | 選擇 npm dist-tag |
| `-PackageManager auto\|npm\|pnpm` | 沿用記錄的管理器，或選擇現有可用 pnpm/npm |
| `-PackageVersion <semver>` | 安裝指定精確版本 |
| `-FetchRetries 0..10` | 本次執行的下載重試次數，預設 4 |
| `-FetchTimeoutSeconds 30..900` | 本次執行的單請求超時，預設 300 秒 |
| `-NetworkConcurrency 1..50` | registry 併發連線數，預設 15 |
| `-DownloadAttempts 1..3` | 同一精確版本的安裝嘗試次數，預設 2 |
| `-NativeBuildTools auto\|skip` | 檢查 Ubuntu 原生編譯依賴，或明確跳過 |
| `-AcceptPrerelease` | 明確允許 RC/beta |
| `-Yes` | 接受顯示的包與 prerequisite 改動 |
| `-WhatIf` | 預覽改動；metadata 檢查仍可能聯網 |
| `-SkipNodeInstall` | 缺少相容 Linux Node 時直接失敗 |
| `-InstallWslIfMissing:$true` | 明確允許新增 WSL/Ubuntu；預設 false |

## 安裝器會修改什麼？

根據當前狀態，它可能：

- 透過官方 `wsl --install` 新增 Ubuntu 24.04；
- 安裝缺少的 `git`、`curl`、CA certificates、`build-essential` 和 Python 3；
- 使用固定 nvm tag，並核對 commit 後安裝當前 Node.js LTS；
- 備份 `~/.profile`，再新增帶 marker 的最小 nvm 或 npm prefix/PATH 區塊；
- 當 `/usr` 不可寫時使用使用者目錄 `~/.local`，絕不使用 `sudo npm -g`；
- 透過 npm 或已存在的 Linux pnpm 安裝精確版本 `@deepseek-ai/dsh`；
- 在 `~/.local/state/deepseek-harness-wsl/` 寫入不含 secret 的版本與回滾記錄。

它不會修改預設發行版、轉換 WSL1、編輯 `.wslconfig`、VPN、DNS、防火牆或代理，不會公開監聽 Web UI、儲存 API key、刪除工作區或取消註冊發行版。

## 常見問題

### Windows 變慢或 `vmmem` 很大

先檢查 `wsl --list --running`，以及 Harness、Docker、測試或其他 Linux 工作是否仍在執行。關閉瀏覽器標籤不一定會終止 Harness server 或子程序。

不要直接貼上通用 `memory=2GB` 配置。該上限會影響所有 WSL2 發行版，也沒有與會話數量對應的 DeepSeek 官方公式。`wsl --shutdown` 會終止所有執行中的發行版，因此本專案不會自動執行它。

WSL2 使用動態擴充套件虛擬磁碟。刪除 Linux 檔案會降低 guest 檔案系統用量，但不保證 host 上的 VHD 檔案立即縮小。請遵循 Microsoft 當前磁碟管理指南，不要直接刪除或編輯 `ext4.vhdx`。

### npm 無權寫入 `/usr/lib/node_modules`

系統 Node 可能可用，但 npm global prefix `/usr` 對普通使用者不可寫。重新執行本 Skill；它會選擇 `~/.local` 並持久化受管理 PATH。不要使用 `sudo npm install --global`、遞迴修改 `/usr` 所有權或自動刪除疑似殘留目錄。

### registry metadata 正常，但某個 `.tgz` 超時

metadata 和 tarball 是不同 HTTP 請求。安裝器只對已驗證的同一精確版本做有界重試，並保持官方 registry、TLS 與 integrity 檢查。不要使用非官方鏡像、`strict-ssl=false`、`curl -k` 或 `npm cache clean --force`；切換 pnpm 也不能保證改變網路路由。

較慢網路可顯式降低併發並增加有限等待：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deepseek-harness-wsl\scripts\setup-deepseek-harness-wsl.ps1 -Action install -FetchRetries 6 -FetchTimeoutSeconds 600 -NetworkConcurrency 4 -DownloadAttempts 3 -AcceptPrerelease -Yes
```

### `node-pty` 或 node-gyp 編譯失敗

預設 `-NativeBuildTools auto` 會檢查 `make`、Python 3、GCC 和 G++。Ubuntu 缺件時只重新整理 apt index 並安裝必要包，不執行完整 `apt upgrade`。如果 agent 無法互動輸入 sudo 密碼，安裝器會停止並列印使用者可在 WSL 終端執行的恢復命令，不會偷偷改用 root。

### `dsh` 已安裝但命令找不到

Windows 發起的非 login WSL 命令不一定讀取 `~/.profile`。狀態檢查會直接解析並驗證受管理的 `dsh` 絕對路徑，不會 source 任意使用者 profile，也不會透過向 `.bashrc`、`.npmrc` 重複寫設定來掩蓋問題。

## 解除安裝

只移除 Harness：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deepseek-harness-wsl\scripts\setup-deepseek-harness-wsl.ps1 -Action uninstall -Yes
```

移除 Node.js、使用者設定、WSL 發行版或 WSL 本身屬於獨立高風險操作，不在此命令範圍內。

## 主要來源

- [DeepSeek Harness 官方儲存庫](https://github.com/deepseek-ai/deepseek-harness)
- [DeepSeek Harness 原始碼開發要求](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/development.md)
- [DeepSeek Windows PowerShell 支援說明](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/feature/2026-08-01-windows-pwsh-default.md)
- [DeepSeek per-session agent 測量](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/architecture/2026-08-03-per-session-agent-presets.md)
- [DeepSeek 大型 session 恢復測量](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/architecture/2026-08-05-large-session-jsonl-restore-pipeline.md)
- [DeepSeek V4 技術報告](https://arxiv.org/html/2606.19348v1)
- [Microsoft：安裝 WSL](https://learn.microsoft.com/windows/wsl/install)
- [Microsoft：WSL 高階設定](https://learn.microsoft.com/windows/wsl/wsl-config)
- [Microsoft：管理 WSL 磁碟空間](https://learn.microsoft.com/windows/wsl/disk-space)
- [Microsoft：WSL 基本命令](https://learn.microsoft.com/windows/wsl/basic-commands)
- [npm install 文件](https://docs.npmjs.com/cli/commands/npm-install/)
- [pnpm request 設定](https://pnpm.io/settings#request-settings)
- [node-pty Linux 構建依賴](https://github.com/microsoft/node-pty#dependencies)
- [node-gyp Unix prerequisites](https://github.com/nodejs/node-gyp#on-unix)

## License

[MIT](LICENSE)
