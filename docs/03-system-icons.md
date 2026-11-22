# 系统图标：此电脑 / 回收站 / 控制面板

这三项不是 `.lnk`，而是 Shell 命名空间对象，改图标要走注册表的 `DefaultIcon`。这里记的是实测通过的路径与两个坑。

---

## 1. 生效位置

真正被 shell 读取的是 **`Explorer\CLSID` 下的覆盖键**（HKLM 与 HKCU 各写一份更稳）：

```
HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CLSID\{CLSID}\DefaultIcon
HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CLSID\{CLSID}\DefaultIcon
```

值：`(default)` = `C:\Icons\此电脑.ico,0`

| 对象 | CLSID |
|---|---|
| 此电脑 | `{20D04FE0-3AEA-1069-A2D8-08002B30309D}` |
| 回收站 | `{645FF040-5081-101B-9F08-00AA002F954E}` |
| 控制面板（桌面显示的那一枚） | `{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}` |
| 控制面板（传统 CLSID） | `{21EC2020-3AEA-1069-A2DD-08002B30309D}` |
| 所有控制面板项 | `{26EE0668-A00A-44D7-9371-BEB064C98683}` |

### 怎么确认桌面那一枚的真实 CLSID

```powershell
$shell = New-Object -ComObject Shell.Application
foreach ($it in $shell.NameSpace(0).Items()) { "$($it.Name) => $($it.Path)" }
```

输出里 `控制面板 => ::{5399E694-...}` 就是它。**只写 `{21EC2020…}` 和 `{26EE0668…}` 不会改变桌面这一枚**——这是最容易返工的一处。

---

## 2. 回收站的两个状态

同一 CLSID 下用 `Empty` 与 `Full` 两个值切换：

```
...\CLSID\{645FF040-5081-101B-9F08-00AA002F954E}\DefaultIcon
  (default) = C:\Icons\Bin_Empty.ico,0
  Empty     = C:\Icons\Bin_Empty.ico,0
  Full      = C:\Icons\Bin_Full.ico,0
```

桶里没东西读 `Empty`，有文件读 `Full`。想立刻看满桶版：删一个文件进回收站即可。

两版建议同角色、同构图，只改「桶身实心度 / 桶内内容 / 表情 / 回收标完整度」，否则会像换了个图标而不是同一个对象的两种状态。

---

## 3. 两个坑

### 3.1 `HKLM\SOFTWARE\Classes\CLSID` 写不进去

```
Requested registry access is not allowed.
```

这些 CLSID 键的所有者是 `TrustedInstaller`，管理员进程也写不了。**不要夺取所有权**，直接改用上面的 `Explorer\CLSID` 覆盖键即可（实测有效）。

### 3.2 改完必须重启 explorer

`ie4uinit.exe -show` 只刷新快捷方式图标，对命名空间图标无效：

```powershell
Stop-Process -Name explorer -Force
Start-Process explorer.exe
```

重启会关掉所有资源管理器窗口，不影响已打开的程序。

---

## 4. 备份与回滚

改前导出：

```powershell
& "$env:SystemRoot\System32\reg.exe" export `
  "HKLM\SOFTWARE\Classes\CLSID\{645FF040-5081-101B-9F08-00AA002F954E}\DefaultIcon" `
  .\backup\bin_defaulticon.reg /y
```

回滚 = 导入备份 + 删除 `Explorer\CLSID` 下新增的 `DefaultIcon` 子键（HKLM/HKCU 都删），再重启 explorer。

> 注意：删除覆盖键后，系统会回落到 `Classes\CLSID` 的原值（`imageres.dll,-55` 之类），不需要手动重建。

---

## 5. 脚本化

本仓库不提供自动改注册表的脚本（不同机器 CLSID 有变体，写死风险高）。建议手工执行、逐步核验：

1. 先写 HKCU 一份 → 重启 explorer → 看是否生效；
2. 生效后再补 HKLM（可选）；
3. 每次只改一个对象，避免一次全改后无法定位问题。
