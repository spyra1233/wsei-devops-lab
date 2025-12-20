# Laboratorium 6 – Continuous Delivery (CD)

## Prerekwizyty
1. **Subskrypcja Azure** (Azure for Students)
2. **Azure CLI** zainstalowane
3. **Konto GitHub**

---

## 📋 Struktura laboratorium

W tym laboratorium nauczysz się:
1. ✅ Budować i deployować aplikację .NET do Azure Container Apps przez GitHub Actions
2. ✅ Wdrażać aplikację z użyciem Canary Deployment (automatyczny 20% traffic split)
3. ✅ Stopniowo zwiększać ruch do nowej wersji (20% → 50% → 100%)
4. ✅ Monitorować deployment w czasie rzeczywistym

---

## Przygotowanie

### 0.1 Fork repozytorium GitHub

1. Przejdź do: `https://github.com/rcialowicz/wsei-devops-lab`
2. Kliknij **Fork** (prawy górny róg)
3. Sklonuj swojego forka:

```powershell
git clone https://github.com/<twoja-nazwa>/wsei-devops-lab.git
cd wsei-devops-lab
```

### 0.2 Zaloguj się do Azure CLI

```powershell
az login
az account show
az account set --subscription "<your-subscription-id>"
```

### 0.3 Rejestracja dostawców Azure (jeśli wymagane)

Jeśli uruchomisz `deploy-infra.ps1` po raz pierwszy, możesz potrzebować zarejestrować dostawców:

```powershell
az provider register --namespace Microsoft.App --wait
az provider register --namespace Microsoft.ContainerRegistry --wait
```

---

## Ćwiczenie 1 – Pierwszy deployment przez PowerShell

**Cel:** Wdrożyć infrastrukturę i aplikację bezpośrednio z maszyny lokalnej przy użyciu PowerShell

### 1.1 Przejrzyj strukturę aplikacji

```powershell
cd lab6

# Zobacz pliki aplikacji
ls app/

# Zawartość:
# - Program.cs       - kod aplikacji .NET
# - ProductApi.csproj - plik projektu
# - Dockerfile       - definicja kontenera
```

### 1.2 Sprawdź aplikację lokalnie (opcjonalnie)

Aplikacja ma 3 endpointy:
- `/` - zwraca wersję aplikacji
- `/health` - health check endpoint
- `/api/products` - zwraca listę produktów

```csharp
// lab6/app/Program.cs
app.MapGet("/", () => "ProductAPI - Version 1.0 🟢");
app.MapGet("/health", () => new { status = "healthy", version = "1.0" });
app.MapGet("/api/products", () => new[] { ... });
```

### 1.3 Utwórz infrastrukturę

Uruchom skrypt `deploy-infra.ps1` aby stworzyć Resource Group i ACA Environment:

```powershell
.\deploy-infra.ps1 -StudentName "kowalski"
```

Skrypt automatycznie:
- ✅ Tworzy Resource Group: `rg-kowalski-lab6`
- ✅ Tworzy Container Apps Environment: `aca-env-kowalski`

⏱️ **Trwa ~2-3 minuty** (tworzenie ACA Environment)

### 1.4 Deployuj wersję 1.0

Instruktor udostępni Ci następujące informacje:
- `ACR_LOGIN_SERVER` - np. `acrobcialab6.azurecr.io`
- `ACR_USERNAME` - np. `acrobcialab6`
- `ACR_PASSWORD` - hasło ACR

```powershell
.\deploy-app.ps1 `
  -Version 1 `
  -StudentName "kowalski" `
  -AcrLoginServer "acrobcialab6.azurecr.io" `
  -AcrUsername "acrobcialab6" `
  -AcrPassword "HASŁO_OD_INSTRUKTORA"
```

Skrypt automatycznie:
- ✅ Tworzy Container App: `productapi-kowalski`
- ✅ Deployuje obraz v1.0 z instruktorskiego ACR

### 1.5 Pobierz URL aplikacji

Po zakończeniu skryptu:

```powershell
az containerapp show `
  --name "productapi-kowalski" `
  --resource-group "rg-kowalski-lab6" `
  --query properties.configuration.ingress.fqdn `
  -o tsv
```

URL aplikacji: `https://productapi-kowalski.xxx.azurecontainerapps.io`

### 1.6 Przetestuj aplikację

```powershell
$APP_URL = "https://productapi-kowalski.xxx.azurecontainerapps.io"  # ZMIEŃ!

# Test głównego endpointa
curl $APP_URL

# Test health check
curl "$APP_URL/health"

# Test API
curl "$APP_URL/api/products"
```

**Oczekiwany wynik:**
```
ProductAPI - Version 1.0 🟢
```

✅ **Checkpoint:** Aplikacja v1.0 działa w Azure Container Apps!

---

## Ćwiczenie 2 – Update do wersji 2.0 (Canary Deployment 20%)

**Cel:** Wdrożyć nową wersję z automatycznym canary deployment (20% ruchu na nową wersję)

### 2.1 Deployuj wersję 2.0

```powershell
.\deploy-app.ps1 `
  -Version 2 `
  -StudentName "kowalski" `
  -AcrLoginServer "acrobcialab6.azurecr.io" `
  -AcrUsername "acrobcialab6" `
  -AcrPassword "HASŁO_OD_INSTRUKTORA"
```

Skrypt automatycznie:
- ✅ Deployuje obraz Docker v2.0 z instruktorskiego ACR
- ✅ Deployuje nową rewizję do Container App
- ✅ **Ustawia 20% ruchu na v2.0, 80% na v1.0 (Canary!)**

⏱️ **Trwa ~30-60 sekund** (tylko deployment)

### 2.2 Utwórz skrypt monitorowania ruchu

Stwórz własny skrypt PowerShell do śledzenia podziału ruchu (curl w pętli).

Zapisz ten kod do pliku np. `test-traffic.ps1` i uruchom go:

### 2.3 Uruchom monitoring

---

## Ćwiczenie 3 – Stopniowe zwiększanie ruchu (50% i 100%)

**Cel:** Rozszerzyć pipeline o stopniowe przełączanie ruchu: 20% → 50% → 100%

### 3.1 Przygotuj zmienne środowiskowe

```powershell
$NAZWISKO = "kowalski"  # ZMIEŃ TO!
$RESOURCE_GROUP = "rg-$NAZWISKO-lab6"
$APP_NAME = "productapi-$NAZWISKO"
```

### 3.2 Zwiększ ruch do 50% (canary expansion)

```powershell
# Pobierz rewizje posortowane po dacie utworzenia (najnowsze pierwsze)
$revisionsJson = az containerapp revision list `
  --name $APP_NAME `
  --resource-group $RESOURCE_GROUP `
  --query "[?properties.active] | sort_by(@, &properties.createdTime) | reverse(@)" `
  -o json | ConvertFrom-Json

$latestRevision = $revisionsJson[0].name
$previousRevision = $revisionsJson[1].name

Write-Host "Najnowsza (50%): $latestRevision"
Write-Host "Poprzednia (50%): $previousRevision"

# Ustaw 50/50 traffic split
az containerapp ingress traffic set `
  --name $APP_NAME `
  --resource-group $RESOURCE_GROUP `
  --revision-weight "$latestRevision=50" "$previousRevision=50"

Write-Host "[OK] Traffic ustawiony na 50/50" -ForegroundColor Green
```

### 3.3 Monitoruj nowy podział ruchu

Twój skrypt `test-traffic.ps1` powinien być nadal uruchomiony.  
Po 20-30 sekundach zobaczysz zmianę podziału ruchu:

```
📊 Stats: v1.0=25 (50%) | v2.0=25 (50%) | Errors=0
```

**📸 ZADANIE:** Zrób screenshot pokazujący podział ~50/50 i wyślij prowadzącemu.

### 3.4 Pełne przełączenie na v2.0 (100%)

```powershell
# Przełącz 100% ruchu na nową wersję
az containerapp ingress traffic set `
  --name $APP_NAME `
  --resource-group $RESOURCE_GROUP `
  --revision-weight "$latestRevision=100"

Write-Host "✅ Full rollout: 100% traffic to v2.0" -ForegroundColor Green
```

### 3.5 Zweryfikuj pełne przełączenie

Po ~20 sekundach wszystkie requesty powinny zwracać v2.0:

```
Request 101 | v2.0 🔵
Request 102 | v2.0 🔵
Request 103 | v2.0 🔵
...

📊 Stats: v1.0=0 (0%) | v2.0=100 (100%) | Errors=0
```

✅ **Checkpoint:** Pełny rollout zakończony! 100% ruchu na v2.0.

**📸 ZADANIE:** Zrób screenshot pokazujący 100% ruchu na v2.0 i wyślij prowadzącemu.

---

## 🎓 Podsumowanie i ocena

### Co należy przesłać prowadzącemu:

1. **3 screenshoty/logi** pokazujące:
   - ✅ Canary 20% (v2.0) / 80% (v1.0)
   - ✅ Traffic split 50% / 50%
   - ✅ Full rollout 100% (v2.0)

2. **URL aplikacji** działającej w Azure Container Apps

---

## Cleanup

```powershell
# Usuń Resource Group (wszystkie zasoby)
az group delete --name $RESOURCE_GROUP --yes --no-wait
```

---
