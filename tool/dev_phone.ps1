<#
Chạy app trên điện thoại thật (cắm USB) cùng backend trên máy tính.

  1. Bật backend (cửa sổ "Tron backend") nếu cổng 5080 chưa có ai chạy.
  2. Chờ backend sẵn sàng (/api/v1/health/ready).
  3. adb reverse: localhost:5080 trên điện thoại trỏ về máy tính, không cần
     IP Wi-Fi hay mở tường lửa.
  4. flutter run với API_BASE_URL=http://localhost:5080.

Cách dùng (từ thư mục gốc repo):
  powershell -ExecutionPolicy Bypass -File tool/dev_phone.ps1
  powershell -ExecutionPolicy Bypass -File tool/dev_phone.ps1 -d <mã thiết bị>
  powershell -ExecutionPolicy Bypass -File tool/dev_phone.ps1 -BackendOnly

Tham số không nhận ra được chuyển thẳng cho `flutter run`.
-BackendOnly chỉ làm bước 1–3 (dùng cho preLaunchTask của VS Code).
Rút cáp rồi cắm lại thì chạy lại script để nối lại cổng.
#>
param(
  [switch]$BackendOnly,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$FlutterArgs
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$port = 5080
# 127.0.0.1 thay cho localhost: trên Windows localhost thử IPv6 trước (~2 giây).
$healthUrl = "http://127.0.0.1:$port/api/v1/health/ready"

function Test-BackendReady {
  try {
    $res = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 2
    return $res.StatusCode -eq 200
  } catch {
    return $false
  }
}

function Test-PortInUse {
  $conn = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
  return $null -ne $conn
}

function Find-Adb {
  $cmd = Get-Command adb -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }

  $sdks = @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT)
  $props = Join-Path $root 'android\local.properties'
  if (Test-Path $props) {
    $line = Select-String -Path $props -Pattern '^sdk\.dir=(.+)$' | Select-Object -First 1
    if ($line) { $sdks += ($line.Matches[0].Groups[1].Value -replace '\\\\', '\') }
  }
  $sdks += (Join-Path $env:LOCALAPPDATA 'Android\Sdk')

  foreach ($sdk in $sdks) {
    if (-not $sdk) { continue }
    $adb = Join-Path $sdk 'platform-tools\adb.exe'
    if (Test-Path $adb) { return $adb }
  }
  return $null
}

# 1–2. Backend
if (Test-BackendReady) {
  Write-Host "Backend đã chạy sẵn ở cổng $port."
} else {
  if (Test-PortInUse) {
    Write-Host "Cổng $port đang có chương trình chạy nhưng chưa sẵn sàng, chờ thêm..."
  } else {
    Write-Host "Đang bật backend trong cửa sổ 'Tron backend' (đóng cửa sổ đó để tắt backend)..."
    $command = "`$Host.UI.RawUI.WindowTitle = 'Tron backend'; dotnet run --project src/Tron.Api"
    Start-Process powershell -WorkingDirectory (Join-Path $root 'backend') `
      -ArgumentList '-NoExit', '-NoProfile', '-Command', $command
  }

  $deadline = (Get-Date).AddSeconds(120)
  while (-not (Test-BackendReady)) {
    if ((Get-Date) -gt $deadline) {
      Write-Host ''
      Write-Error ("Backend không sẵn sàng sau 120 giây. Xem lỗi trong cửa sổ 'Tron backend' " +
        "(thường do SQL Server trên máy chưa chạy).")
    }
    Write-Host -NoNewline '.'
    Start-Sleep -Seconds 2
  }
  Write-Host ''
  Write-Host "Backend sẵn sàng: http://localhost:$port"
}

# 3. Nối cổng điện thoại về máy tính
$adb = Find-Adb
if (-not $adb) {
  Write-Warning 'Không tìm thấy adb.exe (Android SDK platform-tools). App trên điện thoại sẽ không gọi được backend.'
} else {
  $serials = & $adb devices |
    Where-Object { $_ -match '^(\S+)\s+device$' } |
    ForEach-Object { $Matches[1] }

  if (-not $serials) {
    Write-Warning 'Chưa thấy thiết bị Android nào. Cắm USB, bật "Gỡ lỗi USB" và chấp nhận trên điện thoại rồi chạy lại.'
  }
  foreach ($serial in $serials) {
    & $adb -s $serial reverse "tcp:$port" "tcp:$port" | Out-Null
    if ($LASTEXITCODE -eq 0) {
      Write-Host "Đã nối localhost:$port trên $serial về máy tính."
    } else {
      Write-Warning "adb reverse lỗi trên $serial."
    }
  }
}

if ($BackendOnly) { exit 0 }

# 4. Chạy app
Set-Location $root
& flutter run "--dart-define=API_BASE_URL=http://localhost:$port" @FlutterArgs
exit $LASTEXITCODE
