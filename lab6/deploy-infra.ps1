# ============================================
# Lab6 - Infrastructure Deployment Script
# ============================================
# Skrypt tworzy infrastrukturę (Resource Group, ACA Environment, Container App)
# Użycie: .\deploy-infra.ps1 -StudentName "kowalski"

param(
    [Parameter(Mandatory=$true)]
    [string]$StudentName,
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "francecentral"
)

# Inicjalizacja
$StudentName = $StudentName.ToLower()
$ResourceGroup = "rg-$StudentName-lab6"
$AcaEnv = "aca-env-$StudentName"
$AppName = "productapi-$StudentName"

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Lab6 - Infrastructure Deployment" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Student: $StudentName" -ForegroundColor Yellow
Write-Host "Location: $Location" -ForegroundColor Yellow
Write-Host ""

# Sprawdzenie Azure logowania
Write-Host "[1/3] Sprawdzanie Azure logowania..." -ForegroundColor Yellow
try {
    $account = az account show 2>&1 | ConvertFrom-Json
    Write-Host "[OK] Zalogowany jako: $($account.user.name)" -ForegroundColor Green
} catch {
    Write-Host "[FAILED] Nie jestes zalogowany do Azure. Uruchom: az login" -ForegroundColor Red
    exit 1
}

# Tworzenie Resource Group
Write-Host "`n[2/3] Tworzenie Resource Group: $ResourceGroup..." -ForegroundColor Yellow
$rgExists = az group exists --name $ResourceGroup
if ($rgExists -eq "true") {
    Write-Host "[!] Resource Group juz istnieje" -ForegroundColor DarkYellow
} else {
    az group create --name $ResourceGroup --location $Location --output none
    Write-Host "[OK] Resource Group utworzony" -ForegroundColor Green
}

# Tworzenie Container Apps Environment
Write-Host "`n[3/3] Tworzenie Container Apps Environment: $AcaEnv..." -ForegroundColor Yellow
$envExists = az containerapp env show --name $AcaEnv --resource-group $ResourceGroup 2>$null
if ($envExists) {
    Write-Host "[!] Environment juz istnieje" -ForegroundColor DarkYellow
} else {
    Write-Host "   (To moze potrwac 2-3 minuty...)" -ForegroundColor Gray
    az containerapp env create `
        --name $AcaEnv `
        --resource-group $ResourceGroup `
        --location $Location `
        --logs-destination none `
        --output none
    Write-Host "[OK] Environment utworzony" -ForegroundColor Green
}

# Podsumowanie
Write-Host "`n=====================================" -ForegroundColor Cyan
Write-Host "[OK] Infrastruktura gotowa!" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[*] Utworzone zasoby:" -ForegroundColor Yellow
Write-Host "   Resource Group: $ResourceGroup" -ForegroundColor White
Write-Host "   Environment: $AcaEnv" -ForegroundColor White
Write-Host "   App Name: $AppName" -ForegroundColor White
Write-Host ""
Write-Host "[>] Nastepny krok:" -ForegroundColor Cyan
Write-Host "   Uruchom deploy-app.ps1 aby wdrozyc aplikacje" -ForegroundColor Gray
