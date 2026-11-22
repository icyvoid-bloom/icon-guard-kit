<#
install_icon_guard.ps1 — 注册图标守卫为登录自启的计划任务

用法：
  pwsh -NoProfile -File .\install_icon_guard.ps1
  pwsh -NoProfile -File .\install_icon_guard.ps1 -ConfigPath C:\Tools\icon-guard\config.json -TaskName IconGuard -DelaySeconds 20

说明：
  - 以当前用户身份、最高权限、仅登录时运行（静默，无 UAC 弹窗）
  - 优先使用 PowerShell 7；没有则用系统自带 powershell.exe
  - 需要管理员权限才能创建 Highest 级别的任务
#>
[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'icon_guard_config.json'),
    [string]$TaskName   = 'IconGuard',
    [int]$DelaySeconds  = 20,
    [string]$Interpreter = ''
)

$ErrorActionPreference = 'Stop'

$guard = Join-Path $PSScriptRoot 'icon_guard.ps1'
if (-not (Test-Path -LiteralPath $guard)) { throw "找不到 icon_guard.ps1：$guard" }

$cfgFull = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($ConfigPath))
if (-not (Test-Path -LiteralPath $cfgFull)) { throw "找不到配置文件：$cfgFull" }

if (-not $Interpreter) {
    $preferred = @(
        'C:\Program Files\PowerShell\7\pwsh.exe',
        "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    )
    $Interpreter = $preferred | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $Interpreter) { throw '找不到可用的 PowerShell 解释器' }
Write-Verbose "interpreter: $Interpreter"

$me = "$env:USERDOMAIN\$env:USERNAME"

$argLine = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -ConfigPath "{1}"' -f $guard, $cfgFull

$action = New-ScheduledTaskAction -Execute $Interpreter -Argument $argLine -WorkingDirectory $PSScriptRoot
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $me
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew -StartWhenAvailable `
    -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
$principal = New-ScheduledTaskPrincipal -UserId $me -LogonType Interactive -RunLevel Highest

if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings `
    -Principal $principal -Description '图标守卫：恢复被软件重写的快捷方式图标' | Out-Null

$task = Get-ScheduledTask -TaskName $TaskName
$task.Triggers[0].Delay = "PT$([int]$DelaySeconds)S"
Set-ScheduledTask -TaskName $TaskName -Trigger $task.Triggers | Out-Null

$task = Get-ScheduledTask -TaskName $TaskName
Write-Host ("任务: {0} / {1}" -f $task.TaskName, $task.State)
Write-Host ("身份: {0} / {1} / {2}" -f $task.Principal.UserId, $task.Principal.RunLevel, $task.Principal.LogonType)
Write-Host ("触发: 登录后 {0} 秒" -f $DelaySeconds)
Write-Host ("配置: {0}" -f $cfgFull)
