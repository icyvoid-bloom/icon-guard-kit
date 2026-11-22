<#
uninstall_icon_guard.ps1 — 删除图标守卫任务并结束后台进程
用法：pwsh -NoProfile -File .\uninstall_icon_guard.ps1 -TaskName IconGuard

只结束「本任务」拉起的守卫进程：按任务动作里的脚本路径 + 配置路径匹配，
不会误杀其它用同名脚本但不同配置的守卫实例。
#>
[CmdletBinding()]
param([string]$TaskName = 'IconGuard')

$scriptPath = $null
$configPath = $null

$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($task) {
    $action = $task.Actions | Select-Object -First 1
    if ($action -and $action.Arguments) {
        if ($action.Arguments -match '-File\s+"([^"]+)"') { $scriptPath = $matches[1] }
        if ($action.Arguments -match '-ConfigPath\s+"([^"]+)"') { $configPath = $matches[1] }
    }
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "已删除计划任务：$TaskName"
} else {
    Write-Host "未找到计划任务：$TaskName"
}

if ($scriptPath) {
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" -ErrorAction SilentlyContinue |
        Where-Object {
            $_.CommandLine -and
            $_.CommandLine.IndexOf($scriptPath, [StringComparison]::OrdinalIgnoreCase) -ge 0 -and
            (-not $configPath -or $_.CommandLine.IndexOf($configPath, [StringComparison]::OrdinalIgnoreCase) -ge 0)
        } |
        ForEach-Object {
            try {
                Stop-Process -Id $_.ProcessId -Force
                Write-Host ("已结束守卫进程 PID={0}" -f $_.ProcessId)
            } catch {
                Write-Host ("结束进程失败 PID={0}: {1}" -f $_.ProcessId, $_.Exception.Message)
            }
        }
} else {
    Write-Host '任务动作里没有解析到脚本路径，跳过结束进程。'
}

Write-Host '快捷方式图标保持不变；需要恢复默认时手动把 IconLocation 改成 ",0"。'
