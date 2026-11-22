<#
interactive_icon.ps1 — 双击 一键生成图标.bat 后运行的交互向导
只做三件事：问路径 → 调 make_icon.ps1 → 告诉你产物在哪。
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$make = Join-Path $PSScriptRoot 'make_icon.ps1'

function Read-PathInput([string]$Prompt) {
    $v = Read-Host $Prompt
    if (-not $v) { return '' }
    return $v.Trim().Trim('"').Trim("'")
}

Write-Host '================================================' -ForegroundColor Cyan
Write-Host '  图标一键生成  |  icon-guard-kit' -ForegroundColor Cyan
Write-Host '  把图片文件拖到本窗口，回车即可' -ForegroundColor Cyan
Write-Host '================================================' -ForegroundColor Cyan

$art = Read-PathInput '1. 图片路径（拖文件进来）'
if (-not $art) { Write-Host '没有输入路径，已退出。' -ForegroundColor Yellow; return }
if (-not (Test-Path -LiteralPath $art)) {
    Write-Host ("找不到文件：{0}" -f $art) -ForegroundColor Red
    return
}

$name = Read-Host '2. 底部文字（可留空，直接用文件名）'
$lnk = Read-PathInput '3. 要替换的快捷方式路径（不需要就直接回车）'
if ($lnk -and -not (Test-Path -LiteralPath $lnk)) {
    Write-Host ("找不到快捷方式：{0}，这次只生成不替换。" -f $lnk) -ForegroundColor Yellow
    $lnk = ''
}

Write-Host ''
Write-Host '正在生成，请稍等……' -ForegroundColor DarkGray

$params = @{ Art = $art }
if ($name) { $params.Name = $name }
if ($lnk)  { $params.Lnk = $lnk }

& $make @params
