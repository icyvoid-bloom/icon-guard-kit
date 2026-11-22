# 工作流：从参考图到桌面生效

一条可复用的流水线。按「5 个图标一组」推进，每组走完 7 步。

---

## 0. 前置

- Windows 10/11，Python 3.9+
- `pip install pillow numpy`
- 不需要 ImageMagick / ffmpeg

---

## 1. 定风格与配色

先写清楚每个图标的三件事：

| 要素 | 说明 |
|---|---|
| 角色依据 | 有官方/二创拟人就沿用；没有就用某个动漫角色做原型，**只借气质与构图，不描摹原图** |
| 品牌色 | 从当前桌面图标或品牌规范里取 2–3 个主色，作为发色/服装/饰品的落点 |
| 识别点 | 1–2 件能一眼认出的饰物（耳机、麦克风、盾牌、手柄…），不要堆满 |

同厂软件要成组设计：同色系 + 可区分结构。例如网盘类统一构图、创意套件统一版式、只改主色。

---

## 2. 出主图

提示词不用自己编：`prompts/03_提示词模板.txt` 填四个空即可，写法见 `prompts/01_主提示词.md`，现成例子见 `prompts/02_示例提示词.md`。

- 尺寸 1024×1024 起步（生成模型用 1536 也可以，最后缩到 1024）。
- 人物**偏上构图**：头肩占画面上 55–65%，底部留出约 15% 给标签栏。
- 背景简洁：单色渐变或轻光效，别放文字、别放品牌 logo。
- 平涂优先；避免 3D 渲染、厚涂、写实皮肤——缩到 48 px 会糊成噪点。
- 需要透明背景时，输出 PNG 带 alpha。

---

## 3. 合成六尺寸 ico

最省事的方式（自动选 Python、自动核对依赖、附送核对 PNG）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\make_icon.ps1 `
  -Art ".\app_1024.png" -Name "App Name"
```

或者双击根目录 `一键生成图标.bat`，按提示拖图、填字即可。手动调参时用下面的原始命令：
python .\tools\build_ico.py `
  --input  .\app_1024.png `
  --output .\App.ico `
  --text   "App Name" `
  --head-x 0.50 --head-y 0.42 --face-crop 0.36
```

参数含义：

| 参数 | 作用 |
|---|---|
| `--head-x/--head-y` | 16 px 头像帧的取景中心（归一化 0–1） |
| `--face-crop` | 16 px 头像帧的取景边长占比，默认 0.36，越小脸越大 |
| `--crop` | 主图取景占比，默认 1.0（整图居中）；一般不用改 |
| `--text` | 标签栏文字；留空则不加文字 |
| `--shape` | 外轮廓：`rounded`（默认，圆角矩形）或 `superellipse` |
| `--radius` | 圆角半径占画布比例，默认 0.23 |
| `--no-bar` / `--no-text` | 不加底栏 / 不加底栏文字 |
| `--emit-png` | 额外导出 1024 与各尺寸 PNG，便于核对 |

输出：一个含 6 帧的 `.ico`，另存 `*_1024.png`、`*_{尺寸}.png` 方便核对。

**取景区一定要在 16 px 下验证**：写脚本把 16 px 放大到 250 px 加十字中线，逐张看脸是否居中。改 `head-y` 会让脸上下移，改 `head-x` 左右移；不同图会有轻微非线性，迭代 2–4 轮即可。

---

## 4. 替换图标

### 普通快捷方式

```powershell
pwsh -NoProfile -File .\tools\apply_icon.ps1 `
  -Lnk "$env:USERPROFILE\Desktop\App.lnk" `
  -Ico "C:\Icons\App.ico" `
  -BackupDir .\backup
```

`-BackupDir` 会写一份 JSON，记录原 `target / arguments / workingDirectory / iconLocation`，用于回滚。

### 系统图标（此电脑 / 回收站 / 控制面板）

不能用 `.lnk` 方式，必须改注册表覆盖键，见 `docs/03-system-icons.md`。

### 文件夹或 exe 图标

需要改 exe 资源或用第三方 shell 扩展；本项目不覆盖这条路径。

---

## 5. 刷新图标缓存

```powershell
& "$env:SystemRoot\System32\ie4uinit.exe" -show
```

普通 `.lnk` 通常立刻生效。系统命名空间图标**必须重启 explorer**：

```powershell
Stop-Process -Name explorer -Force
Start-Process explorer.exe
```

---

## 6. 核验

- 截桌面，按网格逐格比对（图标中心横坐标固定，行距固定）。
- 看三种尺寸：桌面默认（约 48 px）、小图标视图（32 px）、列表视图（16 px）。
- 重点看 16 px 是否还能认出「发色 + 脸」，认不出就回去调 `--head-x/--head-y/--face-crop`。

---

## 7. 记录与回滚

| 产物 | 内容 |
|---|---|
| `backup/<App>_icon.json` | 替换前 `IconLocation` 等 |
| 注册表 `.reg` 备份 | 系统图标原值 |
| 变更说明 `.md` | 改了哪些键、哪些文件、如何撤回 |

回滚原则：**只回滚你改过的字段**，不要整表恢复，避免覆盖用户后续的合法修改。

---

## 8. 守住成果

软件更新会重写快捷方式。把这类应用加进 `icon_guard` 清单，由后台脚本自动恢复图标：

```
docs/04-icon-guard.md
```

这一步是整条流水线的「最后一公里」，也是最容易被忽略的一步。
