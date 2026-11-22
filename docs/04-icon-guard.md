# 图标守卫（icon_guard）

核心工具。解决的问题只有一句话：**软件会重写自己的桌面快捷方式，守卫把图标改回来，其它字段一律不动。**

---

## 1. 问题是什么

三种典型场景：

| 场景 | 表现 |
|---|---|
| 版本目录型客户端（部分国产客户端、游戏启动器） | 安装/升级后按 `D:\App\<版本>\app.exe` 重建 `.lnk`，图标回落 exe 自带 |
| Squirrel 更新的 Electron 应用（Discord、Slack 等） | 更新器把快捷方式指向 `app-<版本>` 并重建，图标丢失 |
| 每次启动都"修复"快捷方式的应用 | 用户手动改好，下次启动又变回去 |

两种常见但无效的做法：

- **给 `.lnk` 加只读 / 拒绝写入**：软件升级需要更新目标路径，锁死后快捷方式指向已删除的旧 exe，直接打不开。
- **替换 exe 内嵌图标**：每次更新覆盖，且破坏数字签名。

所以只能「事后纠正」：监听 `.lnk` 变化，发现图标不对就只改回 `IconLocation`。

---

## 2. 设计要点

### 2.1 只改一个字段

用 `WScript.Shell` 打开快捷方式，只设置：

```powershell
$sc = $sh.CreateShortcut($lnk)
$sc.IconLocation = "$ico,0"
$sc.Save()
```

`TargetPath / Arguments / WorkingDirectory / Hotkey / WindowStyle` 保持软件刚写进去的值。这样版本更新后目标自动跟着变，守卫不需要知道版本号。

### 2.2 用「修改时间 + 文件长度」做变更指纹

`Get-Item` 的 `LastWriteTimeUtc.Ticks` 与 `Length` 组合，成本极低（微秒级），比哈希整个文件快得多，也足够判断"被重写过"。

状态表按路径缓存，未变化时完全不碰 COM 对象。

### 2.3 变更后主动通知 shell

```csharp
SHChangeNotify(SHCNE_UPDATEITEM, SHCNF_PATHW, lnkPath, 0)
```

否则资源管理器可能继续显示缓存里的旧图标。

### 2.4 单实例

命名互斥量 `Local\IconGuard`，防止登录任务与手动调试同时跑、互相抢文件。

### 2.5 日志与轮转

追加写 `icon_guard.log`；超过 1 MB 自动转存 `.old`，避免长期运行撑爆磁盘。

---

## 3. 配置

`tools/icon_guard_config.json`：

```json
{
  "poll_seconds": 2,
  "log_file": ".\\icon_guard.log",
  "targets": [
    {
      "lnk": "C:\\Users\\Public\\Desktop\\SomeApp.lnk",
      "ico": "C:\\Icons\\SomeApp.ico",
      "note": "可选：备注，仅用于人读"
    }
  ]
}
```

| 字段 | 说明 |
|---|---|
| `poll_seconds` | 轮询间隔，默认 2；低于 1 会被校正为 2 |
| `log_file` | 可选；相对路径按**配置文件所在目录**解析 |
| `targets[].lnk` | 要守的快捷方式 |
| `targets[].ico` | 目标 ico；实际写入 `"<ico>,0"` |

路径支持 `%ENV%` 展开；相对路径相对配置文件目录。建议 `.ico` 用绝对路径，避免工作目录变化导致失效。

---

## 4. 部署

### 4.1 先单次测试

```powershell
pwsh -NoProfile -File .\tools\icon_guard.ps1 -Once -Verbose
```

`-Once` 只扫一遍就退出，适合验证配置对不对。

### 4.2 注册登录任务

```powershell
pwsh -NoProfile -File .\tools\install_icon_guard.ps1 `
  -ConfigPath .\tools\icon_guard_config.json `
  -TaskName IconGuard `
  -DelaySeconds 20
```

生成的任务：

| 项 | 值 |
|---|---|
| 触发 | 当前用户登录后延迟 N 秒 |
| 权限 | `RunLevel = Highest`、`LogonType = Interactive` |
| 执行 | 优先 `pwsh 7`，没有则用系统自带 `powershell.exe` |
| 行为 | 隐藏窗口；无超时限制；崩溃自动重启 3 次；不重复启动 |

> 用 `Highest` 的原因：部分客户端以管理员权限重建快捷方式，普通权限进程可能无法覆盖它写出的文件。

### 4.3 卸载

```powershell
pwsh -NoProfile -File .\tools\uninstall_icon_guard.ps1 -TaskName IconGuard
```

删任务 + 结束正在运行的守卫进程；快捷方式保持当前图标。

---

## 5. 运行行为

```
[2026-01-01 09:00:00] guard started: 2 target(s), poll 2s
[2026-01-01 09:00:04] restored App.lnk: C:\App\1.2\app.exe,0 -> C:\Icons\App.ico,0 (target C:\App\1.2\app.exe)
```

界面表现：打开软件瞬间图标可能闪一下默认图标，1–2 秒内自动恢复，之后保持正常。

资源占用：常驻一个 PowerShell 进程，约 20–30 MB 内存，CPU 接近 0（每 2 秒两次 `Get-Item`）。

---

## 6. 排错

| 现象 | 原因 | 处理 |
|---|---|---|
| 日志里没有记录 | 配置没被读到 / 任务没起 | 先 `-Once -Verbose` 手动跑；再看任务状态是否 Running |
| 记录了"恢复"但桌面没变 | Explorer 图标缓存 | 加 `ie4uinit.exe -show`；仍不行则重启 explorer |
| 报 `Requested registry access is not allowed` | 那是注册表脚本的问题，不是守卫 | 见 `docs/03-system-icons.md` |
| 连续 `处理失败` | 文件被占用（软件正在写） | 正常瞬时现象；持续失败就关掉软件再观察 |
| 任务显示"正在运行"很久 | 守卫是常驻进程，属正常 | 不处理；`LastTaskResult = 0x41301` 也是"正在运行" |
| 图标被改回旧的自定义图 | 配置里的 `ico` 没跟着更新 | 改配置后重启任务 |

---

## 7. 边界与限制

1. **只处理 `.lnk`**。系统命名空间图标（此电脑/回收站/控制面板）不走这条路，见 `docs/03-system-icons.md`。
2. **只认配置里的路径**。如果软件把快捷方式改名重建（例如生成 `App (1).lnk`），守卫不会接管，需要手工删掉多余的那个。
3. **不修复图标文件本身**。`ico` 被移动或删除后，守卫只能记录失败；建议把 ico 放在稳定目录并纳入备份。
4. **不做图标缓存重建**。极端情况下 Explorer 会顽固缓存，需要重启 explorer 或清理 `IconCache.db`。
5. **不适用于多用户同时登录的场景**：任务按当前用户注册，别的账户登录不会启动。
6. **一台机器只跑一个实例**：靠 `Local\IconGuard` 互斥量保证；有多份清单时合并进同一份配置的 `targets`，不要注册多个任务。

---

## 8. 安全说明

- 守卫只调用 `WScript.Shell` 读写指定 `.lnk` 的 `IconLocation`，不执行目标程序、不注入进程、不联网。
- 以最高权限运行只为覆盖管理员进程写出的文件；脚本不修改注册表。
- 建议把脚本与配置放在**非用户可写目录**（如 `C:\Tools\icon-guard`），避免被同机低权限程序篡改后随登录提权执行。
