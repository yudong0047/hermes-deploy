<#
  DSH Desktop 启动失败 · 自动诊断与修复脚本
  适用：Windows 10/11，DSH Desktop（@deepseek-ai/dsh-desktop）
  用法：
    1. 完全退出 DSH Desktop（任务管理器结束所有 DSH 相关进程）
    2. 右键本文件 →「使用 PowerShell 运行」；或打开 PowerShell 执行：
       powershell -ExecutionPolicy Bypass -File .\dsh_diag_fix.ps1
    3. 只诊断不修复：加参数 -DiagnoseOnly
    4. 允许改文件：加参数 -Fix

  设计原则：
    · 先诊断、后修复；修复前必做备份（打 zip 到 %TEMP%\dsh-backup-<时间戳>.zip）
    · 所有动作都写日志到 $ReportPath，便于回传
    · 不删除任何用户数据（会话/任务/凭据），只动 node_modules 与缓存
#>

[CmdletBinding()]
param(
    [switch]$DiagnoseOnly,
    [switch]$Fix,
    [string]$AppData = $env:APPDATA
)

$ErrorActionPreference = 'Continue'
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$ReportPath = Join-Path $env:TEMP "dsh-diag-$Stamp.txt"
$Log = New-Object System.Collections.Generic.List[string]

function Write-Log {
    param([string]$Msg, [string]$Level = 'INFO')
    $Line = "[{0}] {1,-5} {2}" -f (Get-Date -Format 'HH:mm:ss'), $Level, $Msg
    Write-Host $Line
    $Log.Add($Line) | Out-Null
}

function Section { param([string]$T) Write-Log "===== $T =====" 'HEAD' }

# ── 路径定义 ────────────────────────────────────────────────
$DesktopDir = Join-Path $AppData '@deepseek-ai\dsh-desktop'
$LogsDir    = Join-Path $DesktopDir 'logs'
$DiagDir    = Join-Path $DesktopDir 'diagnostics'
$DshHome    = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $env:USERPROFILE '.dsh' }
$ProfileDir = Join-Path $DshHome 'profiles\desktop'

Write-Log "DSH Desktop 诊断开始（$Stamp）" 'HEAD'
Write-Log "APPDATA      = $AppData"
Write-Log "DSH_HOME     = $DshHome"
Write-Log "桌面数据目录 = $DesktopDir"
Write-Log "Profile 目录 = $ProfileDir"
Write-Log "模式: $(if($DiagnoseOnly){'仅诊断'}elseif($Fix){'诊断+修复'}else{'诊断(加 -Fix 才动手)'})"

# ── 0. 进程占用检查 ─────────────────────────────────────────
Section '步骤 0：检查是否有 DSH 进程在跑（文件被占用会导致修复失败）'
$procs = Get-Process -ErrorAction SilentlyContinue |
    Where-Object { $_.ProcessName -match 'dsh|harness|deepseek' }
if ($procs) {
    Write-Log "发现 $($procs.Count) 个相关进程仍在运行：" 'WARN'
    $procs | ForEach-Object { Write-Log "   PID $($_.Id)  $($_.ProcessName)" 'WARN' }
    Write-Log "请先在任务管理器中结束它们，再重新运行本脚本。" 'WARN'
    $Script:HasRunningProc = $true
} else {
    Write-Log "没有 DSH 进程占用，可以安全操作。" 'OK'
    $Script:HasRunningProc = $false
}

# ── 1. 版本与安装信息 ───────────────────────────────────────
Section '步骤 1：版本与安装位置'
$exeCandidates = @(
    "$env:LOCALAPPDATA\Programs\DeepSeek Harness\DeepSeek Harness.exe",
    "$env:LOCALAPPDATA\Programs\dsh-desktop\DSH Desktop.exe",
    "$env:ProgramFiles\DSH Desktop\DSH Desktop.exe",
    "$env:ProgramFiles\DeepSeek Harness\DeepSeek Harness.exe"
)
$foundExe = $exeCandidates | Where-Object { Test-Path $_ }
if ($foundExe) {
    foreach ($e in $foundExe) {
        $vi = (Get-Item $e).VersionInfo
        Write-Log "找到安装: $e"
        Write-Log "   文件版本 = $($vi.FileVersion) / 产品版本 = $($vi.ProductVersion)"
    }
} else {
    Write-Log "未在常见路径找到可执行文件（可能装在非标准位置或已卸载）。" 'WARN'
}
try {
    $cmd = Get-Command dsh -ErrorAction Stop
    Write-Log "CLI dsh 路径: $($cmd.Source)"
    $v = (& dsh --version 2>&1 | Select-Object -First 1)
    Write-Log "CLI dsh 版本: $v"
} catch {
    Write-Log "未找到 dsh CLI（桌面版自带，不装 CLI 也正常）。" 'INFO'
}

# ── 2. 崩溃日志采集 ─────────────────────────────────────────
Section '步骤 2：崩溃日志（这是定位根因的关键）'
$crashFiles = @()
if (Test-Path $LogsDir) {
    $crashFiles = Get-ChildItem $LogsDir -Filter 'crash*.log' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 5
    if ($crashFiles) {
        foreach ($f in $crashFiles) {
            Write-Log "崩溃日志: $($f.Name)  [$($f.LastWriteTime)]  $([math]::Round($f.Length/1KB,1)) KB"
        }
    } else {
        Write-Log "logs 目录里没有 crash*.log（若能进主界面但功能异常，看同目录其它 .log）。" 'INFO'
    }
    Write-Log "logs 目录全部文件："
    Get-ChildItem $LogsDir -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 12 |
        ForEach-Object { Write-Log "   $($_.Name)  [$($_.LastWriteTime)]" }
} else {
    Write-Log "日志目录不存在: $LogsDir" 'WARN'
}

# ── 3. 错误模式识别 ─────────────────────────────────────────
Section '步骤 3：错误模式识别（对照已知故障库）'
$Findings = New-Object System.Collections.Generic.List[object]
function Add-Finding {
    param([string]$Pattern, [string]$Diagnosis, [string]$Fix, [string]$Severity, [string]$Evidence)
    $Findings.Add([pscustomobject]@{
        Pattern=$Pattern; Diagnosis=$Diagnosis; Fix=$Fix; Severity=$Severity; Evidence=$Evidence
    }) | Out-Null
}

$allLogText = ''
if ($crashFiles) {
    foreach ($f in $crashFiles) {
        try { $allLogText += (Get-Content $f.FullName -Raw -ErrorAction Stop) } catch {}
    }
}
# 也扫同目录其它日志，扩大命中面
if (Test-Path $LogsDir) {
    Get-ChildItem $LogsDir -Filter '*.log' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike 'crash*' } |
        Select-Object -First 8 | ForEach-Object {
            try { $allLogText += (Get-Content $_.FullName -Raw -ErrorAction Stop) } catch {}
        }
}

if ($allLogText.Trim()) {
    Write-Log "已读取日志文本，共 $([math]::Round($allLogText.Length/1KB,1)) KB" 'OK'

    if ($allLogText -match 'command runtime directory contains unexpected entries') {
        Add-Finding 'runtime-directory-unexpected-entries' `
          '运行时目录里混入了不该存在的文件（常见于旧版本残留 DLL/tessdata/tesseract.exe）。典型报错词：unexpected entries + libarchive/libbrotli/libtiff 等一堆 dll。' `
          '删除 DSH 桌面端的运行时目录后重装；重装无效说明是用户数据目录被污染。' `
          'HIGH' "命中: command runtime directory contains unexpected entries"
    }
    if ($allLogText -match 'Web authentication failed|HTTP 431|431 Request Header Fields Too Large') {
        Add-Finding 'web-auth-431-cookie-bloat' `
          'Cookie 累积过多把请求头撑爆（HTTP 431）。已知案例：SQLite 里攒到 71 条 cookie 后必崩。报错被统一包装成"Web authentication failed"，极具误导性。' `
          '清理 cookie 存储 / 会话数据后重启；错误信息指向"认证"但真凶在浏览器存储。' `
          'HIGH' "命中: Web authentication failed / 431"
    }
    if ($allLogText -match 'Failed plugins.*tools|@deepseek-ai/dsh-tools.*failed to import') {
        Add-Finding 'mock-dsh-tools-blocks-core-tools' `
          'profile 的 node_modules 里存在多余的 @deepseek-ai/dsh-tools（mock/残留），会遮蔽核心 tools 插件，直接导致启动失败并自动进安全模式。' `
          '删除该重复包目录后完全退出重开。' `
          'HIGH' "命中: Failed plugins / dsh-tools failed to import"
    }
    if ($allLogText -match 'Cannot read properties of undefined.*prepare') {
        Add-Finding 'duplicate-dsh-tools-symbol-identity' `
          '同一个 @deepseek-ai/dsh-tools 在模块图里存在两份拷贝，agent loop 与工具运行时 import 到不同副本，Symbol 标识不一致导致工具查找返回 undefined。仅在调用工具时崩，纯文本对话正常。' `
          '移除 profile 内的第二份拷贝（先移到一边做对照测试，不要直接永久删除）。' `
          'MEDIUM' "命中: Cannot read properties of undefined (reading 'prepare')"
    }
    if ($allLogText -match 'INTERFACE_MISMATCH') {
        Add-Finding 'interface-mismatch' '插件接口版本与当前 DSH 不匹配。' '回滚或更新该插件到与当前 dsh 版本兼容的版本。' 'MEDIUM' '命中: INTERFACE_MISMATCH'
    }
    if ($allLogText -match 'WORKSPACE_INVALID') { Add-Finding 'workspace-invalid' '工作区配置非法/失效。' '检查 profile 的 workspace 配置项。' 'LOW' '命中: WORKSPACE_INVALID' }
    if ($allLogText -match 'PERMISSION_DENIED') { Add-Finding 'permission-denied' '存储权限不足。' '检查 %APPDATA% 与安装目录的写入权限，或以管理员身份重试。' 'MEDIUM' '命中: PERMISSION_DENIED' }
    if ($allLogText -match 'phase:\s*startup') { Write-Log "失败发生在【启动阶段】" 'INFO' }
    if ($allLogText -match 'phase:\s*(?!startup)') { }
    if ($allLogText -match 'safe.?mode|安全模式') { Write-Log "日志提到安全模式 —— 说明曾被自动降级" 'WARN' }
    if ($allLogText -match 'ECONNREFUSED|ENOTFOUND|ETIMEDOUT') { Write-Log "日志含网络错误（可能只是模型端点问题，不一定是启动失败根因）" 'INFO' }

    # 打印关键错误行
    Write-Log "---- 日志中的关键错误行 ----" 'HEAD'
    $errLines = $allLogText -split "`r?`n" | Where-Object {
        $_ -match 'Error|error:|FAILED|Failed|failed|Unexpected|unexpected|fatal|FATAL'
    } | Select-Object -First 25
    if ($errLines) { $errLines | ForEach-Object { Write-Log "   $_" } }
    else { Write-Log "   （未捕获到明显 error 行）" }
} else {
    Write-Log "没读到日志文本，将依赖文件结构与模式 B/C 检查。" 'WARN'
}

# ── 4. 重复 dsh-tools 检查（文件系统层）──────────────────────
Section '步骤 4：检查 profile 内是否有重复的 dsh-tools 包'
$dupRoots = @()
foreach ($base in @($ProfileDir, $DshHome)) {
    if (Test-Path $base) {
        $dupRoots += Get-ChildItem $base -Recurse -Directory -Filter 'dsh-tools' -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match 'node_modules' -and $_.FullName -match '@deepseek-ai' }
    }
}
if ($dupRoots) {
    Write-Log "发现 $($dupRoots.Count) 处 @deepseek-ai/dsh-tools：" 'WARN'
    $dupRoots | ForEach-Object { Write-Log "   $($_.FullName)" 'WARN' }
    Add-Finding 'filesystem-duplicate-dsh-tools' `
      "文件系统中发现 $($dupRoots.Count) 处 @deepseek-ai/dsh-tools，profile 内的那份会遮蔽核心 tools 插件。" `
      '将 profile 内那处重命名为 dsh-tools.bak-<时间戳>（可回滚），完全退出 DSH 后重开。' `
      'HIGH' "文件扫描命中 $($dupRoots.Count) 处"
} else {
    Write-Log "未发现重复的 dsh-tools 包。" 'OK'
}

# ── 5. profile 依赖中的 link: 悬空引用 ───────────────────────
Section '步骤 5：检查 profile 依赖里的 link: 悬空引用'
$pkgJson = Join-Path $ProfileDir 'package.json'
if (Test-Path $pkgJson) {
    try {
        $pkg = Get-Content $pkgJson -Raw | ConvertFrom-Json
        $deps = @{}
        if ($pkg.dependencies) { $deps = $pkg.dependencies }
        if ($pkg.devDependencies) { $pkg.devDependencies.PSObject.Properties | ForEach-Object { $deps[$_.Name] = $_.Value } }
        $dangling = @()
        foreach ($k in $deps.Keys) {
            $v = [string]$deps[$k]
            if ($v -like 'link:*' -or $v -like 'file:*') {
                $p = $v -replace '^(link|file):',''
                if ($p -notmatch '^\w+@') { $p = Join-Path $ProfileDir $p }
                if (-not (Test-Path $p)) { $dangling += "$k -> $v" }
            }
        }
        if ($dangling) {
            Write-Log "发现悬空依赖 $($dangling.Count) 条：" 'WARN'
            $dangling | ForEach-Object { Write-Log "   $_" 'WARN' }
            Add-Finding 'dangling-link-dependency' 'profile 依赖里有指向不可读目录的 link:/file: 引用。' '编辑 package.json 移除这些条目后重装依赖。' 'MEDIUM' "命中 $($dangling.Count) 条"
        } else {
            Write-Log "依赖引用均有效。" 'OK'
        }
        # bundles 清单
        if ($pkg.dsh -and $pkg.dsh.profile -and $pkg.dsh.profile.bundles) {
            Write-Log "已启用 bundle：" 'INFO'
            $pkg.dsh.profile.bundles | ForEach-Object { Write-Log "   $_" }
        }
    } catch {
        Write-Log "解析 package.json 失败: $($_.Exception.Message)" 'WARN'
    }
} else {
    Write-Log "未找到 $pkgJson（若从未用过 CLI 属正常）。" 'INFO'
}

# ── 6. 诊断结果汇总 ─────────────────────────────────────────
Section '===== 诊断结论 ====='
if ($Findings.Count -eq 0) {
    Write-Log "未匹配到已知故障模式。" 'OK'
    Write-Log "可能原因：① 升级后版本不兼容（新旧文件混装）② 用户数据目录损坏 ③ 磁盘/权限问题"
    Write-Log "建议直接用【模式 B】重置用户数据目录，或【模式 C】重装最新版。"
} else {
    $Findings | ForEach-Object {
        Write-Log "[$($_.Severity)] $($_.Diagnosis)" $_.Severity
        Write-Log "    证据: $($_.Evidence)"
        Write-Log "    对策: $($_.Fix)"
    }
}

# ── 7. 修复动作 ─────────────────────────────────────────────
if ($Fix -and -not $DiagnoseOnly) {
    Section '步骤 7：执行修复'
    if ($Script:HasRunningProc) {
        Write-Log "仍有进程占用，修复已跳过。请先结束进程再运行。" 'ERROR'
    } else {
        # 7.1 备份
        $backup = Join-Path $env:TEMP "dsh-backup-$Stamp.zip"
        try {
            $items = @()
            foreach ($d in @($DesktopDir, $ProfileDir)) { if (Test-Path $d) { $items += $d } }
            if ($items.Count -gt 0) {
                Compress-Archive -Path $items -DestinationPath $backup -Force -ErrorAction Stop
                Write-Log "已备份到: $backup  ($([math]::Round((Get-Item $backup).Length/1KB,1)) KB)" 'OK'
            } else {
                Write-Log "没有可备份的目录（目录不存在）。" 'WARN'
            }
        } catch {
            Write-Log "备份失败（继续，但请自行确认可回滚）: $($_.Exception.Message)" 'WARN'
        }

        # 7.2 修重复 dsh-tools
        $dupFix = $Findings | Where-Object { $_.Pattern -match 'duplicate-dsh-tools' }
        if ($dupFix) {
            foreach ($d in $dupRoots) {
                if ($d.FullName -like "$ProfileDir*") {
                    $bak = "$($d.FullName).bak-$Stamp"
                    try {
                        Rename-Item $d.FullName $bak -ErrorAction Stop
                        Write-Log "已重命名重复包: $($d.FullName) -> $bak" 'OK'
                    } catch {
                        Write-Log "重命名失败: $($_.Exception.Message)" 'ERROR'
                    }
                }
            }
        }

        # 7.3 修运行时目录（unexpected entries）
        if ($Findings | Where-Object { $_.Pattern -eq 'runtime-directory-unexpected-entries' }) {
            $rtCandidates = @(
                (Join-Path $DshHome 'runtime'),
                (Join-Path $ProfileDir 'runtime'),
                (Join-Path $DesktopDir 'runtime')
            )
            foreach ($rt in $rtCandidates) {
                if (Test-Path $rt) {
                    $rtBak = "$rt.bak-$Stamp"
                    try {
                        Rename-Item $rt $rtBak -ErrorAction Stop
                        Write-Log "运行时目录已隔离: $rt -> $rtBak" 'OK'
                    } catch {
                        Write-Log "隔离运行时目录失败: $($_.Exception.Message)" 'ERROR'
                    }
                }
            }
        }

        Write-Log "修复动作完成。请完全退出 DSH Desktop 后重新启动。" 'HEAD'
        Write-Log "若仍失败，下一步请做【模式 B】：删除用户数据目录（登录后会重新同步）。"
    }
} else {
    Section '步骤 7：修复（未执行）'
    Write-Log "加 -Fix 参数可执行自动修复："
    Write-Log "   powershell -ExecutionPolicy Bypass -File .\dsh_diag_fix.ps1 -Fix"
}

# ── 8. 报告落盘 ─────────────────────────────────────────────
$Log | Out-File -FilePath $ReportPath -Encoding UTF8
Write-Log "" 'HEAD'
Write-Log "诊断报告已保存: $ReportPath" 'OK'
Write-Log "请把该文件内容（或 logs 目录里的 crash*.log）发给我，我来判定根因。"
Write-Log "日志目录: $LogsDir"
Write-Log "崩溃日志若在，优先发最新的 1~2 份。"

Write-Host ""
Write-Host "=== 一句话速览 ===" -ForegroundColor Cyan
if ($Findings.Count -eq 0) {
    Write-Host "未匹配已知模式，建议重置用户数据目录或重装。" -ForegroundColor Yellow
} else {
    $Findings | ForEach-Object { Write-Host "[$($_.Severity)] $($_.Diagnosis)" -ForegroundColor Yellow }
}
Write-Host "报告: $ReportPath"
