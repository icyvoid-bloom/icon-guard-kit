<#
make_icon.ps1 — 一条命令：图片 → 六尺寸 ico →（可选）替换桌面快捷方式
用法：
  powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\make_icon.ps1 -Art "D:\art\app.png" -Name "App"
  ... -Art .\app.png -Name "App" -Lnk "$env:USERPROFILE\Desktop\App.lnk"

参数都可省略，只有 -Art 必填；-Name 留空时用文件名。
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Art,
    [string]$Name = '',
    [string]$OutDir = '',
    [string]$Lnk = '',
    [double]$HeadX = 0.5,
    [double]$HeadY = 0.45,
    [double]$FaceCrop = 0.36,
    [double]$Crop = 1.0
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$build = Join-Path $repo 'tools\build_ico.py'
$apply = Join-Path $repo 'tools\apply_icon.ps1'

# ---------- 源图 ----------
if (-not (Test-Path -LiteralPath $Art)) { throw "找不到图片：$Art" }
$artFull = (Resolve-Path -LiteralPath $Art).Path
$baseName = [IO.Path]::GetFileNameWithoutExtension($artFull)
if (-not $Name) { $Name = $baseName }

$safe = $Name -replace '[\\/:*?"<>|]', '_'
if (-not $OutDir) { $OutDir = Join-Path (Split-Path -Parent $artFull) 'icon_out' }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$ico = Join-Path $OutDir ("{0}.ico" -f $safe)

# ---------- Python ----------
$py = $null
$pyArgs = @()
$cmd = Get-Command python -ErrorAction SilentlyContinue
if ($cmd) { $py = $cmd.Source }
if (-not $py) {
    $cmd = Get-Command py -ErrorAction SilentlyContinue
    if ($cmd) { $py = $cmd.Source; $pyArgs = @('-3') }
}
if (-not $py) { throw '没找到 Python。安装 Python 3.9+ 并勾选 Add to PATH，或改用 py 启动器。' }

& $py @pyArgs -c "import PIL, numpy" 2>$null
if ($LASTEXITCODE -ne 0) { throw '缺少依赖，请先执行：pip install pillow numpy' }

# ---------- 生成 ico ----------
$buildArgs = @(
    $build,
    '--input', $artFull,
    '--output', $ico,
    '--text', $Name,
    '--head-x', $HeadX,
    '--head-y', $HeadY,
    '--face-crop', $FaceCrop,
    '--crop', $Crop,
    '--emit-png'
)
& $py @pyArgs @buildArgs
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $ico)) { throw '合成失败，看上面的报错。' }

$kb = [math]::Round((Get-Item -LiteralPath $ico).Length / 1KB)
Write-Host ''
Write-Host ('图标已生成：{0}（{1} KB，6 帧）' -f $ico, $kb) -ForegroundColor Green
Write-Host ('核对图：{0}_1024.png 与 {0}_16.png' -f (Join-Path $OutDir $safe))
Write-Host '先看 16 px 那张：认不出脸就调 -FaceCrop / -HeadX / -HeadY 重跑。'

# ---------- 可选：替换快捷方式 ----------
if ($Lnk) {
    if (-not (Test-Path -LiteralPath $Lnk)) { throw "找不到快捷方式：$Lnk" }
    $backup = Join-Path $OutDir 'backup'
    & $apply -Lnk $Lnk -Ico $ico -BackupDir $backup
    Write-Host ''
    Write-Host '替换完成。若桌面没变化，按上面的提示刷新图标缓存。' -ForegroundColor Yellow
} else {
    Write-Host ''
    Write-Host '下一步：右键快捷方式 → 属性 → 更改图标 → 选上面的 .ico；'
    Write-Host '或加 -Lnk "<快捷方式路径>" 让脚本直接替换。'
}
