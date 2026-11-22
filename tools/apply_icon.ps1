<#
apply_icon.ps1 — 给单个快捷方式设置图标，并备份原值

用法：
  pwsh -NoProfile -File .\apply_icon.ps1 -Lnk "$env:USERPROFILE\Desktop\App.lnk" -Ico "C:\Icons\App.ico"
  pwsh -NoProfile -File .\apply_icon.ps1 -Lnk ... -Ico ... -BackupDir .\backup

参数：
  -Lnk        目标快捷方式（自动补 .lnk 后缀）
  -Ico        图标文件；只写进 IconLocation，不改目标程序
  -BackupDir  可选：把原 target/arguments/workdir/iconLocation 存成 JSON
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Lnk,
    [Parameter(Mandatory = $true)][string]$Ico,
    [string]$BackupDir = ''
)

$ErrorActionPreference = 'Stop'

$lnkPath = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($Lnk))
if (-not $lnkPath.ToLower().EndsWith('.lnk')) { $lnkPath += '.lnk' }
if (-not (Test-Path -LiteralPath $lnkPath)) { throw "快捷方式不存在：$lnkPath" }

$icoPath = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($Ico))
if (-not (Test-Path -LiteralPath $icoPath)) { throw "图标不存在：$icoPath" }
if ([IO.Path]::GetExtension($icoPath).ToLower() -ne '.ico') { Write-Warning '扩展名不是 .ico，Windows 可能不认' }

Add-Type -Namespace ApplyIconShell -Name Api -MemberDefinition @'
[DllImport("shell32.dll", CharSet = CharSet.Unicode)]
public static extern void SHChangeNotify(int eventId, uint flags, IntPtr item1, IntPtr item2);
'@

$shell = New-Object -ComObject WScript.Shell
$sc = $shell.CreateShortcut($lnkPath)

$before = [ordered]@{
    lnk              = $lnkPath
    target           = $sc.TargetPath
    arguments        = $sc.Arguments
    workingDirectory = $sc.WorkingDirectory
    iconLocation     = $sc.IconLocation
    changedAt        = (Get-Date).ToString('s')
}

if ($BackupDir) {
    $dir = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($BackupDir))
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $name = [IO.Path]::GetFileNameWithoutExtension($lnkPath)
    $file = Join-Path $dir ("{0}_icon.json" -f $name)
    $before | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $file -Encoding UTF8
    Write-Host ("原值已备份：{0}" -f $file)
}

$sc.IconLocation = "$icoPath,0"
$sc.Save()

$ptr = [Runtime.InteropServices.Marshal]::StringToHGlobalUni($lnkPath)
try { [ApplyIconShell.Api]::SHChangeNotify(0x2000, 0x0005, $ptr, [IntPtr]::Zero) }
finally { [Runtime.InteropServices.Marshal]::FreeHGlobal($ptr) }

Write-Host ("已设置：{0}" -f $lnkPath)
Write-Host ("  图标：{0}" -f $sc.IconLocation)
Write-Host ("  目标：{0}" -f $sc.TargetPath)
Write-Host '提示：若桌面仍显示旧图标，执行 ie4uinit.exe -show'
