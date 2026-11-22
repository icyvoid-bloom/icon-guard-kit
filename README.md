# icon-guard-kit

给 Windows 桌面快捷方式换上自定义图标，并**守住它们不被软件更新或启动重写**。仓库只包含代码与流程文档，不含任何图片素材。

> A tiny Windows toolkit for custom desktop-shortcut icons — and for keeping them after apps rewrite their shortcuts.

---

## 为什么需要这个

很多客户端会在启动或更新时**重建自己的桌面快捷方式**：

- 带版本号安装目录的软件（如 `D:\App\<版本>\app.exe`）——每次升级重写 `.lnk`，图标回落到 exe 自带；
- 用 Squirrel 更新的 Electron 应用（工作目录 `app-<版本>`）——更新后快捷方式被替换，图标同样丢失。

给 `.lnk` 加只读或拒绝写入并不能解决：目标路径本身必须随版本变化，锁死会导致升级后快捷方式指向不存在的旧 exe。

`tools/icon_guard.ps1` 的做法是：**只把 `IconLocation` 改回去，原样保留软件写入的新目标、参数和工作目录。**

---

## 仓库内容

| 路径 | 作用 |
|---|---|
| `tools/icon_guard.ps1` | 图标守卫主脚本（轮询 `.lnk` 变更 → 恢复图标 → 通知资源管理器刷新） |
| `tools/icon_guard_config.example.json` | 监控清单示例（`lnk` + `ico`） |
| `tools/install_icon_guard.ps1` | 注册登录时启动的计划任务（隐藏窗口、最高权限、可配置延迟） |
| `tools/uninstall_icon_guard.ps1` | 删除任务并结束后台进程 |
| `tools/apply_icon.ps1` | 给单个 `.lnk` 设置图标，带原值备份 |
| `tools/build_ico.py` | 一张方图 → 256/128/64/48/32/16 六帧 ico（圆角遮罩 + 底部标签栏） |
| `tools/make_icon.ps1` | 一条命令：图片 → ico →（可选）直接替换快捷方式 |
| `tools/interactive_icon.ps1` | 双击向导背后的交互脚本 |
| `一键生成图标.bat` | 双击就能用：拖图片、填文字、可选替换 |
| `prompts/00_从这里开始.md` | **傻瓜式四步流程**（零基础照做） |
| `prompts/01_主提示词.md` | 可直接复制的主提示词、变量写法、负面词 |
| `prompts/02_示例提示词.md` | 六条填好的示例（编辑器 / 短视频 / 游戏 / AI / 系统项 / 安全软件） |
| `prompts/03_提示词模板.txt` | 纯文本模板，复制即用 |
| `docs/01-workflow.md` | 从参考图到桌面生效的完整工作流 |
| `docs/02-spec.md` | 图标视觉规格：遮罩、标签栏、字号自适应、六尺寸降级 |
| `docs/03-system-icons.md` | 此电脑 / 回收站 / 控制面板 的系统图标替换要点 |
| `docs/04-icon-guard.md` | 守卫原理、部署、配置、排错 |
| `docs/05-pitfalls.md` | 实操踩坑清单 |
| `docs/06-publish.md` | 如何把这个仓库传到 GitHub（含不改代码的网页上传路线） |

---

## 快速开始：只想要图标守卫

> 命令里的 `pwsh` 指 PowerShell 7；没装的话换成系统自带的 `powershell.exe`，参数完全一样。

> 想做图标、不想读文档：打开 `prompts/00_从这里开始.md`（傻瓜式四步），或直接双击 `一键生成图标.bat`。

1. 复制一份配置：

```powershell
Copy-Item .\tools\icon_guard_config.example.json .\tools\icon_guard_config.json
```

2. 编辑 `icon_guard_config.json`，把要守的快捷方式和 ico 路径填进去（支持相对路径，相对配置文件所在目录解析）：

```json
{
  "poll_seconds": 2,
  "targets": [
    { "lnk": "%USERPROFILE%\\Desktop\\SomeApp.lnk", "ico": "C:\\Icons\\SomeApp.ico" }
  ]
}
```

3. 先测一遍（单次扫描，不常驻）：

```powershell
pwsh -NoProfile -File .\tools\icon_guard.ps1 -Once -Verbose
```

4. 注册登录自启：

```powershell
pwsh -NoProfile -File .\tools\install_icon_guard.ps1 -ConfigPath .\tools\icon_guard_config.json -DelaySeconds 20
```

5. 看日志：`tools\icon_guard.log`（超过 1 MB 自动转存 `.old`）。

---

## 完整流程（概要）

1. **选参考**：确认角色形象、品牌色，先定配色再动笔。
2. **出主图**：1024 或更高，人物偏上构图，底部预留标签栏压盖区。
3. **合成六尺寸**：`build_ico.py` 切方图、加标签栏、套圆角遮罩、写 ico。
4. **替换**：普通快捷方式用 `apply_icon.ps1`；系统项改注册表（见 `docs/03-system-icons.md`）。
5. **刷新**：`ie4uinit.exe -show`；系统图标需重启 explorer。
6. **守卫**：把被软件重写的快捷方式加入 `icon_guard` 清单。

细节都在 `docs/01-workflow.md`。

---

## 不含什么

本仓库**不包含**任何图标成品、参考图、截图或第三方角色素材。文档中提到的软件名仅用于说明技术现象，相关商标与角色版权归各自权利人所有。

## License

代码以 MIT 许可发布，见 `LICENSE`。文档以 CC BY 4.0 发布。
