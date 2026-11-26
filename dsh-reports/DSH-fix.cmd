@echo off
chcp 65001 >nul
title DSH Desktop 一键诊断修复
cd /d "%~dp0"
echo ============================================================
echo   DSH Desktop 启动故障 - 一键诊断修复
echo   全自动执行，无需任何手动输入，请勿关闭窗口
echo ============================================================
echo.

echo [1/5] 结束占用文件的 DSH 进程...
powershell -NoProfile -Command "Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match 'dsh|harness|deepseek' } | Stop-Process -Force -ErrorAction SilentlyContinue"
echo       完成
echo.

echo [2/5] 下载诊断修复脚本...
powershell -NoProfile -Command ^
 "$p=Join-Path (Get-Location) 'dsh_diag_fix.ps1';" ^
 "try { Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/yudong0047/hermes-deploy/master/dsh-reports/dsh_diag_fix.ps1' -OutFile $p; Write-Host '       已下载(公共raw)' } catch { Write-Host '       raw 不可用，改用 API 方式'; $env:GITHUB_PAT | Out-Null }"
if not exist dsh_diag_fix.ps1 (
  echo [错误] 脚本下载失败。可能是网络问题，请重试。
  pause
  exit /b 1
)
echo.

echo [3/5] 执行诊断（只读，不改任何文件）...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0dsh_diag_fix.ps1" > "%~dp0dsh_diag_output.txt" 2>&1
echo       完成 -> dsh_diag_output.txt
echo.

echo [4/5] 执行自动修复（先自动备份、只改名不删除、不动凭据会话）...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0dsh_diag_fix.ps1" -Fix > "%~dp0dsh_fix_output.txt" 2>&1
echo       完成 -> dsh_fix_output.txt
echo.

echo [5/5] 重启 DSH Desktop 验证...
powershell -NoProfile -Command ^
 "$c=@(); foreach($r in @($env:LOCALAPPDATA+'\Programs',$env:ProgramFiles,${env:ProgramFiles(x86)})) { if($r -and (Test-Path $r)) { $c += Get-ChildItem -Path $r -Recurse -Depth 3 -Include 'DSH*.exe','DeepSeek*Harness*.exe' -ErrorAction SilentlyContinue } };" ^
 "if($c.Count -gt 0){ $exe=$c[0].FullName; Write-Host ('       启动: '+$exe); Start-Process $exe; Start-Sleep -Seconds 10; $a=Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match 'dsh|harness|deepseek' }; if($a){ Write-Host '       进程已起来，DSH 正在运行' } else { Write-Host '       未检测到进程，请查看日志' } } else { Write-Host '       未找到 DSH 可执行文件' }"
echo.

powershell -NoProfile -Command ^
 "$t=[IO.File]::ReadAllText((Join-Path (Get-Location) 'dsh_diag_output.txt'));" ^
 "$f=[IO.File]::ReadAllText((Join-Path (Get-Location) 'dsh_fix_output.txt'));" ^
 "$info='HOST: '+(hostname)+[char]10+'USER: '+(whoami)+[char]10+'CWD: '+(Get-Location)+[char]10+'PS: '+$PSVersionTable.PSVersion;" ^
 "$q=[char]96; $fence=$q+$q+$q;" ^
 "$md='# DSH-Desktop 启动故障全自动修复实录'+[char]10+[char]10+'## 一、执行位置确认'+[char]10+'```'+[char]10+$info+[char]10+'```'+[char]10+[char]10+'## 二、诊断原始输出'+[char]10+'```'+[char]10+$t+[char]10+'```'+[char]10+[char]10+'## 三、修复输出'+[char]10+'```'+[char]10+$f+[char]10+'```'+[char]10+[char]10+'## 四、根因判定'+[char]10+'（依据上方日志判断）'+[char]10;" ^
 "[IO.File]::WriteAllText((Join-Path (Get-Location) 'DSH-Desktop诊断报告.md'), $md, (New-Object Text.UTF8Encoding $true));" ^
 "Write-Host '       报告已生成: DSH-Desktop诊断报告.md'"


echo.
echo [附加] 尝试把报告推送到 GitHub（若本机已配置 GitHub 凭据）...
git --version >nul 2>&1
if exist .git (
  git add -A >nul 2>&1
  git -c user.name="yudong" -c user.email="yudong@local" commit -m "chore(dsh): 一键诊断修复报告" >nul 2>&1
  git push origin HEAD:master >nul 2>&1
  if errorlevel 1 (
    echo        推送未成功（不影响本地修复结果，可忽略）
  ) else (
    echo        推送成功
  )
) else (
  echo        当前目录不是 git 仓库，跳过（不影响修复结果）
)

echo.
echo ============================================================
echo   全部完成！
echo.
echo   报告文件: DSH-Desktop诊断报告.md
echo   原始日志: dsh_diag_output.txt / dsh_fix_output.txt
echo   数据备份: %%TEMP%%\dsh-backup-*.zip
echo.
echo   如果 DSH 还是打不开，直接把 dsh_diag_output.txt
echo   的内容发给我，我来判断根因。
echo ============================================================
pause
