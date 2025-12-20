# ============================================
# Lab6 - Application Deployment Script
# ============================================
# Skrypt deployuje aplikacje z ACR do istniejacy Container App
# Użycie: .\deploy-app.ps1 -Version 1 -StudentName "kowalski" -AcrLoginServer "acr.azurecr.io" -AcrUsername "user" -AcrPassword "pass"

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('1', '2', '3')]
    [string]$Version,
    
    [Parameter(Mandatory=$true)]
    [string]$StudentName,
    
    [Parameter(Mandatory=$true)]
    [string]$AcrLoginServer,
    
    [Parameter(Mandatory=$true)]
    [string]$AcrUsername,
    
    [Parameter(Mandatory=$true)]
    [string]$AcrPassword
)

# Inicjalizacja
$StudentName = $StudentName.ToLower()
$ResourceGroup = "rg-$StudentName-lab6"
$AcaEnv = "aca-env-$StudentName"
$AppName = "productapi-$StudentName"
$ImageName = "productapi"

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Lab6 - Application Deployment" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Student: $StudentName" -ForegroundColor Yellow
Write-Host "Version: v$Version.0" -ForegroundColor Yellow
Write-Host "ACR: $AcrLoginServer" -ForegroundColor Yellow
Write-Host ""

# Sprawdzenie Azure logowania
Write-Host "[1/4] Sprawdzanie Azure logowania..." -ForegroundColor Yellow
try {
    $account = az account show 2>&1 | ConvertFrom-Json
    Write-Host "[OK] Zalogowany jako: $($account.user.name)" -ForegroundColor Green
} catch {
    Write-Host "[FAILED] Nie jestes zalogowany do Azure. Uruchom: az login" -ForegroundColor Red
    exit 1
}

# Sprawdzenie czy Container App istnieje
Write-Host "`n[2/4] Sprawdzanie Container App: $AppName..." -ForegroundColor Yellow
$appExists = az containerapp show --name $AppName --resource-group $ResourceGroup 2>$null
if (-not $appExists) {
    Write-Host "   [!] Container App nie istnieje, tworzę..." -ForegroundColor Gray
    
    $image = "$AcrLoginServer/$ImageName`:$Version.0"
    Write-Host "   Obraz: $image" -ForegroundColor Gray
    
    az containerapp create `
        --name $AppName `
        --resource-group $ResourceGroup `
        --environment $AcaEnv `
        --image $image `
        --registry-server $AcrLoginServer `
        --registry-username $AcrUsername `
        --registry-password $AcrPassword `
        --target-port 8080 `
        --ingress external `
        --min-replicas 1 `
        --max-replicas 3 `
        --revisions-mode multiple
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAILED] Nie udalo sie utworzyc Container App" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "[OK] Container App utworzony (tryb wielorekwizyjny)" -ForegroundColor Green
    
    # Dla pierwszego deploymentu, nie trzeba robic update
    Write-Host "`n=====================================" -ForegroundColor Cyan
    Write-Host "[OK] Pierwszy deployment zakonczony!" -ForegroundColor Green
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "[*] Status:" -ForegroundColor Yellow
    Write-Host "   Wersja: v$Version.0" -ForegroundColor White
    Write-Host "   Obraz: $image" -ForegroundColor White
    Write-Host "   Container App: $AppName" -ForegroundColor White
    Write-Host "   Resource Group: $ResourceGroup" -ForegroundColor White
    exit 0
}

Write-Host "[OK] Container App juz istnieje" -ForegroundColor Green

# Aktualizacja Container App
Write-Host "`n[3/4] Aktualizacja obrazu..." -ForegroundColor Yellow
$image = "$AcrLoginServer/$ImageName`:$Version.0"

Write-Host "   Obraz: $image" -ForegroundColor Gray

# Update Container App
az containerapp update `
    --name $AppName `
    --resource-group $ResourceGroup `
    --image $image

if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAILED] Blad przy aktualizacji obrazu" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Nowa rewizja wdrożona" -ForegroundColor Green

# Konfiguracja canary deployment
Write-Host "`n[4/4] Konfiguracja canary deployment..." -ForegroundColor Yellow

# Get revisions sorted by creation time (newest first)
$revisionsJson = az containerapp revision list `
    --name $AppName `
    --resource-group $ResourceGroup `
    --query "[?properties.active] | sort_by(@, &properties.createdTime) | reverse(@)" `
    -o json | ConvertFrom-Json

if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAILED] Blad przy pobieraniu rewizji" -ForegroundColor Red
    exit 1
}

$revisionCount = $revisionsJson.Count

Write-Host "   Znaleziono rewizji: $revisionCount" -ForegroundColor Gray

if ($revisionCount -ge 2) {
    # Set 20% canary traffic
    $latestRevision = $revisionsJson[0].name
    $previousRevision = $revisionsJson[1].name
    
    Write-Host "   Najnowsza (20%): $latestRevision" -ForegroundColor Gray
    Write-Host "   Poprzednia (80%): $previousRevision" -ForegroundColor Gray
    
    az containerapp ingress traffic set `
        --name $AppName `
        --resource-group $ResourceGroup `
        --revision-weight "$latestRevision=20" "$previousRevision=80"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAILED] Blad przy ustawianiu traffic split" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "[OK] Canary deployment ustawiony (20% nowa, 80% stara)" -ForegroundColor Green
} else {
    Write-Host "[!] Tylko jedna rewizja - ruch 100% na nowa wersje" -ForegroundColor DarkYellow
}

# Podsumowanie
Write-Host "`n=====================================" -ForegroundColor Cyan
Write-Host "[OK] Deployment zakonczony!" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[*] Status:" -ForegroundColor Yellow
Write-Host "   Wersja: v$Version.0" -ForegroundColor White
Write-Host "   Obraz: $image" -ForegroundColor White
Write-Host "   Container App: $AppName" -ForegroundColor White
Write-Host "   Resource Group: $ResourceGroup" -ForegroundColor White
Write-Host ""
