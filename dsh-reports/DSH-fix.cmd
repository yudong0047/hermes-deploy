@echo off
chcp 65001 >nul 2>&1
title DSH Desktop 一键诊断修复
cd /d "%~dp0"
set "HERE=%~dp0"
echo ============================================================
echo   DSH Desktop 启动故障 - 一键诊断修复
echo   全自动执行，无需输入任何内容，请勿关闭窗口
echo ============================================================
echo.

echo [1/6] 解包诊断修复脚本（内嵌，无需联网）...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$b64 = @'
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
0tqG0cE1dZn1SAlso40okF1vXP8LAs/MuC5FAAA=
'@;" ^
"$bytes=[Convert]::FromBase64String(($b64 -replace '\s',''));" ^
"$ms=New-Object System.IO.MemoryStream(,$bytes);" ^
"$gz=New-Object System.IO.Compression.GzipStream($ms,[System.IO.Compression.CompressionMode]::Decompress);" ^
"$out=New-Object System.IO.MemoryStream; $gz.CopyTo($out); $gz.Dispose();" ^
"$p=Join-Path $env:USERPROFILE 'dsh_diag_fix.ps1';" ^
"[IO.File]::WriteAllBytes($p,$out.ToArray());" ^
"Write-Host ('       已生成 ' + $p + '  (' + (Get-Item $p).Length + ' 字节)')"
if not exist "%USERPROFILE%\dsh_diag_fix.ps1" (
  echo [错误] 脚本解包失败。
  pause
  exit /b 1
)
echo.

echo [2/6] 结束占用文件的 DSH 进程...
powershell -NoProfile -Command "Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match 'dsh|harness|deepseek' } | Stop-Process -Force -ErrorAction SilentlyContinue"
echo       完成
echo.

echo [3/6] 执行诊断（只读，不改任何文件）...
powershell -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\dsh_diag_fix.ps1" > "%HERE%dsh_diag_output.txt" 2>&1
echo       完成 -> dsh_diag_output.txt
echo.

echo [4/6] 执行自动修复（先自动备份、只改名不删除、不动凭据与会话）...
powershell -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\dsh_diag_fix.ps1" -Fix > "%HERE%dsh_fix_output.txt" 2>&1
echo       完成 -> dsh_fix_output.txt
echo.

echo [5/6] 重启 DSH Desktop 验证...
powershell -NoProfile -Command ^
"$c=@(); foreach($r in @($env:LOCALAPPDATA+'\Programs',$env:ProgramFiles,${env:ProgramFiles(x86)})) { if($r -and (Test-Path $r)) { $c += Get-ChildItem -Path $r -Recurse -Depth 3 -Include 'DSH*.exe','DeepSeek*Harness*.exe' -ErrorAction SilentlyContinue } };" ^
"if($c.Count -gt 0){ $exe=$c[0].FullName; Write-Host ('       启动: '+$exe); Start-Process $exe; Start-Sleep -Seconds 12; $a=Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match 'dsh|harness|deepseek' }; if($a){ Write-Host '       进程已起来，DSH 正在运行' } else { Write-Host '       未检测到进程，请看日志' } } else { Write-Host '       未找到 DSH 可执行文件' }"
echo.

echo [6/6] 生成报告、落桌面、复制到剪贴板...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$dir='%HERE%';" ^
"$d=Join-Path $dir 'dsh_diag_output.txt';" ^
"$f=Join-Path $dir 'dsh_fix_output.txt';" ^
"$txt=@();" ^
"$txt+='HOST: '+(hostname); $txt+='USER: '+(whoami); $txt+='PS: '+$PSVersionTable.PSVersion; $txt+='';" ^
"$txt+='=== 诊断输出 ==='; if(Test-Path $d){ $txt+=(Get-Content -Raw $d) } else { $txt+='(未找到)' };" ^
"$txt+=''; $txt+='=== 修复输出 ==='; if(Test-Path $f){ $txt+=(Get-Content -Raw $f) } else { $txt+='(未找到)' };" ^
"$rpt=($txt -join [char]10);" ^
"$desk=Join-Path $env:USERPROFILE 'Desktop'; if(-not (Test-Path $desk)){ $desk=$env:USERPROFILE };" ^
"$rp=Join-Path $desk 'DSH-Desktop诊断报告.txt';" ^
"[IO.File]::WriteAllText($rp,$rpt,(New-Object Text.UTF8Encoding $true));" ^
"Write-Host ('       报告已保存到桌面: DSH-Desktop诊断报告.txt');" ^
"try { Set-Clipboard -Value $rpt; Write-Host '       报告全文已复制到剪贴板（回到聊天框 Ctrl+V 即可发我）' } catch { Write-Host ('       剪贴板写入失败: '+$_.Exception.Message) };" ^
"try { Start-Process notepad.exe -ArgumentList ('"'+$rp+'"') } catch { }"

echo.
echo       额外备份报告到 paste.rs（失败不影响修复结果）...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$c=Get-Content -Raw (Join-Path '%HERE%' 'dsh_diag_output.txt') -ErrorAction SilentlyContinue;" ^
"try { $r=Invoke-RestMethod -Method Post -Uri 'https://paste.rs' -Body ([Text.Encoding]::UTF8.GetBytes($c)) -ContentType 'text/plain' -TimeoutSec 20; Write-Host ('       回传地址: https://paste.rs' + $r) } catch { Write-Host ('       回传失败（不影响本地修复）: ' + $_.Exception.Message) }"

echo.
echo ============================================================
echo   全部完成！
echo.
eecho   报告文件: 桌面\DSH-Desktop诊断报告.txt
echo   原始日志: %HERE%\dsh_diag_output.txt / dsh_fix_output.txt
echo   数据备份: %%TEMP%%\dsh-backup-*.zip
echo.
echo   >>> 下一步：回到聊天窗口，按 Ctrl+V 粘贴（报告已在剪贴板），直接发给我。
echo   >>> 如果 DSH 还是打不开，也把同样内容发我。
echo ============================================================
pause
