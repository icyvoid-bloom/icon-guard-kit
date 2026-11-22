<#
icon_guard.ps1 — 守住桌面快捷方式的自定义图标

用法：
  pwsh -NoProfile -File .\icon_guard.ps1 -ConfigPath .\icon_guard_config.json
  pwsh -NoProfile -File .\icon_guard.ps1 -Once -Verbose     # 单次扫描，用于验证配置

行为：
  每隔 poll_seconds 检查配置里的 .lnk；一旦文件被改写、且 IconLocation 不是目标 ico，
  只把 IconLocation 改回去，其它字段（目标/参数/工作目录）保持软件写入的新值。

注意：脚本需保存为 UTF-8 with BOM，否则 Windows PowerShell 5.1 会解析中文出错。
#>
[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'icon_guard_config.json'),
    [switch]$Once
)

$ErrorActionPreference = 'Continue'

function Write-GuardLog {
    param([string]$Message, [string]$LogPath)
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $line = "[$ts] $Message"
    try {
        Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
        $item = Get-Item -LiteralPath $LogPath -ErrorAction SilentlyContinue
        if ($item -and $item.Length -gt 1MB) {
            Move-Item -LiteralPath $LogPath -Destination ($LogPath + '.old') -Force
        }
    } catch { }
    Write-Host $line
}

function Resolve-ConfigPath {
    param([string]$Path)
    $expanded = [Environment]::ExpandEnvironmentVariables($Path)
    if (-not [IO.Path]::IsPathRooted($expanded)) {
        $expanded = Join-Path (Get-Location).Path $expanded
    }
    return [IO.Path]::GetFullPath($expanded)
}

function Resolve-TargetPath {
    param([string]$Path, [string]$BaseDir)
    $expanded = [Environment]::ExpandEnvironmentVariables($Path)
    if (-not [IO.Path]::IsPathRooted($expanded)) {
        $expanded = Join-Path $BaseDir $expanded
    }
    return [IO.Path]::GetFullPath($expanded)
}

function Test-IconMatches {
    param([string]$Current, [string]$Expected)
    if ([string]::IsNullOrWhiteSpace($Current)) { return $false }
    $parts = $Current.Split(',')
    $path = $parts[0].Trim().Trim('"')
    $idx = 0
    if ($parts.Length -gt 1) {
        $parsed = 0
        if ([int]::TryParse($parts[1].Trim(), [ref]$parsed)) { $idx = $parsed }
    }
    $normCurrent = [IO.Path]::GetFullPath($path)
    $normExpected = [IO.Path]::GetFullPath($Expected)
    return (($normCurrent -eq $normExpected) -and ($idx -eq 0))
}

Add-Type -Namespace IconGuardShell -Name Api -MemberDefinition @'
[DllImport("shell32.dll", CharSet = CharSet.Unicode)]
public static extern void SHChangeNotify(int eventId, uint flags, IntPtr item1, IntPtr item2);
'@

function Update-ShellIcon {
    param([string]$Path)
    $ptr = [Runtime.InteropServices.Marshal]::StringToHGlobalUni($Path)
    try {
        [IconGuardShell.Api]::SHChangeNotify(0x2000, 0x0005, $ptr, [IntPtr]::Zero)   # SHCNE_UPDATEITEM | SHCNF_PATHW
    } finally {
        [Runtime.InteropServices.Marshal]::FreeHGlobal($ptr)
    }
}

# ---------- 读取配置 ----------
$cfgFull = Resolve-ConfigPath $ConfigPath
if (-not (Test-Path -LiteralPath $cfgFull)) {
    Write-Error "配置不存在：$cfgFull"
    exit 1
}
$cfgDir = Split-Path -Parent $cfgFull
$cfg = Get-Content -LiteralPath $cfgFull -Raw -Encoding UTF8 | ConvertFrom-Json

$poll = 2
if ($cfg.PSObject.Properties.Name -contains 'poll_seconds' -and $cfg.poll_seconds) {
    $poll = [int]$cfg.poll_seconds
    if ($poll -lt 1) { $poll = 2 }
}

$logPath = Join-Path $cfgDir 'icon_guard.log'
if ($cfg.PSObject.Properties.Name -contains 'log_file' -and $cfg.log_file) {
    $logPath = Resolve-TargetPath $cfg.log_file $cfgDir
}

$targets = @()
foreach ($t in $cfg.targets) {
    if (-not $t.lnk -or -not $t.ico) { continue }
    $targets += [pscustomobject]@{
        Lnk  = Resolve-TargetPath $t.lnk $cfgDir
        Ico  = Resolve-TargetPath $t.ico $cfgDir
        Note = $t.note
    }
}
if ($targets.Count -eq 0) {
    Write-Error '配置里没有任何有效 targets'
    exit 1
}

# ---------- 单实例 ----------
$mutex = $null
if (-not $Once) {
    try {
        $mutex = New-Object System.Threading.Mutex($false, 'Local\IconGuard')
        if (-not $mutex.WaitOne(0)) {
            Write-Verbose '已有实例在运行，退出'
            exit 0
        }
    } catch {
        Write-Verbose '互斥量创建失败，继续运行'
    }
}

Write-GuardLog -Message ("guard started: {0} target(s), poll {1}s" -f $targets.Count, $poll) -LogPath $logPath

$state = @{}
foreach ($t in $targets) { $state[$t.Lnk] = '' }

$sh = New-Object -ComObject WScript.Shell

function Invoke-Pass {
    param($Targets, $State, $Shell, $LogPath)

    foreach ($t in $Targets) {
        $lnk = $t.Lnk
        if (-not (Test-Path -LiteralPath $lnk)) { continue }

        try {
            $item = Get-Item -LiteralPath $lnk -ErrorAction Stop
            $stamp = "$($item.LastWriteTimeUtc.Ticks)/$($item.Length)"
            if ($State[$lnk] -eq $stamp) { continue }

            $sc = $Shell.CreateShortcut($lnk)
            if (-not (Test-IconMatches -Current $sc.IconLocation -Expected $t.Ico)) {
                $old = $sc.IconLocation
                $sc.IconLocation = "$($t.Ico),0"
                $sc.Save()
                Update-ShellIcon $lnk
                Write-GuardLog -Message ("restored {0}: {1} -> {2},0 (target {3})" -f (Split-Path $lnk -Leaf), $old, $t.Ico, $sc.TargetPath) -LogPath $LogPath
            } else {
                Write-Verbose ("ok: {0}" -f (Split-Path $lnk -Leaf))
            }

            $item2 = Get-Item -LiteralPath $lnk -ErrorAction SilentlyContinue
            if ($item2) { $State[$lnk] = "$($item2.LastWriteTimeUtc.Ticks)/$($item2.Length)" }
        } catch {
            Write-GuardLog -Message ("failed {0}: {1}" -f $lnk, $_.Exception.Message) -LogPath $LogPath
        }
    }
}

if ($Once) {
    Invoke-Pass -Targets $targets -State $state -Shell $sh -LogPath $logPath
    Write-GuardLog -Message 'single pass done' -LogPath $logPath
    exit 0
}

while ($true) {
    Invoke-Pass -Targets $targets -State $state -Shell $sh -LogPath $logPath
    Start-Sleep -Seconds $poll
}
