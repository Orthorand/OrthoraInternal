# ============================================================
# Build Orthora iOS TIPA từ Windows
# ============================================================
# Cách này dùng GitHub Actions để build trên macOS cloud
# Không cần Mac, không cần jailbreak build tools trên Windows
# ============================================================

param(
    [string]$Action = "push",  # push | trigger
    [string]$RepoUrl = ""      # Ví dụ: https://github.com/YOUR_USER/orthora.git
)

Write-Host "╔═══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     BUILD ORTHORA iOS TIPA TỪ WINDOWS           ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

if ($Action -eq "push") {
    if ([string]::IsNullOrEmpty($RepoUrl)) {
        Write-Host "❌ Cần nhập RepoUrl. Ví dụ:" -ForegroundColor Red
        Write-Host "   .\build_from_windows.ps1 -RepoUrl https://github.com/yourname/orthora.git" -ForegroundColor Yellow
        exit 1
    }

    $ProjectRoot = "C:\Users\ngvie\Desktop\liqimibi"

    Write-Host "[1/4] Khởi tạo git repo..." -ForegroundColor Green
    Set-Location $ProjectRoot
    git init 2>$null
    git add -A
    git commit -m "update $(Get-Date -Format 'yyyy-MM-dd HH:mm')"

    Write-Host "[2/4] Push lên GitHub..." -ForegroundColor Green
    git remote remove origin 2>$null
    git remote add origin $RepoUrl
    git branch -M main
    git push -u origin main --force

    Write-Host "[3/4] Vào GitHub Actions..." -ForegroundColor Green
    Write-Host ""
    Write-Host "   👉 Mở link sau trong browser:" -ForegroundColor Yellow
    Write-Host "      $($RepoUrl.Replace('.git',''))/actions" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   👉 Click workflow 'Build Orthora iOS TIPA'" -ForegroundColor Yellow
    Write-Host "   👉 Click 'Run workflow' → 'Run workflow'" -ForegroundColor Yellow
    Write-Host "   👉 Đợi 5-10 phút → Download Artifacts (.tipa)" -ForegroundColor Yellow

    Write-Host ""
    Write-Host "[4/4] Install lên iPhone:" -ForegroundColor Green
    Write-Host "   1. AirDrop file .tipa từ artifacts xuống iPhone" -ForegroundColor White
    Write-Host "   2. Mở trong TrollStore → Install" -ForegroundColor White
    Write-Host "   3. Mở 'Orthora Patch' → chọn region → Patch Hack" -ForegroundColor White
    Write-Host "   4. Chạy game → dylib auto inject" -ForegroundColor White
    Write-Host ""
    Write-Host "✅ Done!" -ForegroundColor Green
}
elseif ($Action -eq "trigger") {
    Write-Host "🔄 Trigger GitHub Actions workflow..." -ForegroundColor Green
    Write-Host ""
    Write-Host "   Cần GitHub CLI (gh) để trigger từ command line:" -ForegroundColor Yellow
    Write-Host "   gh workflow run build.yml --repo YOUR_USER/orthora" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   Hoặc vào GitHub website → Actions → Run workflow" -ForegroundColor Yellow
}
else {
    Write-Host "Usage: .\build_from_windows.ps1 -Action push -RepoUrl <url>" -ForegroundColor Yellow
}
