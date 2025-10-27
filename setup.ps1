# Blue/Green Deployment Setup Script for Windows
# Run this with: .\setup.ps1

Write-Host " Setting up Blue/Green Deployment..." -ForegroundColor Cyan

# Load environment variables
if (Test-Path .env) {
    Get-Content .env | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            [Environment]::SetEnvironmentVariable($name, $value, "Process")
            Write-Host "✓ Loaded: $name" -ForegroundColor Green
        }
    }
} else {
    Write-Host ".env file not found! Please create it first." -ForegroundColor Red
    exit 1
}

# Determine backup pool
$ACTIVE_POOL = [Environment]::GetEnvironmentVariable("ACTIVE_POOL", "Process")
$BACKUP_POOL = if ($ACTIVE_POOL -eq "blue") { "green" } else { "blue" }
$PORT = [Environment]::GetEnvironmentVariable("PORT", "Process")

Write-Host "Active Pool: $ACTIVE_POOL" -ForegroundColor Yellow
Write-Host "Backup Pool: $BACKUP_POOL" -ForegroundColor Yellow

# Generate nginx.conf from template
Write-Host "`Generating nginx.conf..." -ForegroundColor Cyan

$template = Get-Content nginx.conf.template -Raw
$config = $template -replace '\$\{ACTIVE_POOL\}', $ACTIVE_POOL
$config = $config -replace '\$\{BACKUP_POOL\}', $BACKUP_POOL
$config = $config -replace '\$\{PORT\}', $PORT

$config | Set-Content nginx.conf

Write-Host "✓ nginx.conf generated successfully!" -ForegroundColor Green

# Stop existing containers
Write-Host "`Stopping existing containers..." -ForegroundColor Cyan
docker-compose down 2>$null

# Start services
Write-Host "`Starting services..." -ForegroundColor Cyan
docker-compose up -d

# Wait for services to be ready
Write-Host "` Waiting for services to start..." -ForegroundColor Cyan
Start-Sleep -Seconds 10

# Check service status
Write-Host "`n📊 Service Status:" -ForegroundColor Cyan
docker-compose ps

# Test the deployment
Write-Host "` Testing deployment..." -ForegroundColor Cyan

try {
    $response = Invoke-WebRequest -Uri "http://localhost:8080/version" -UseBasicParsing
    Write-Host "✓ Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "✓ X-App-Pool: $($response.Headers['X-App-Pool'])" -ForegroundColor Green
    Write-Host "✓ X-Release-Id: $($response.Headers['X-Release-Id'])" -ForegroundColor Green
} catch {
    Write-Host " Failed to connect to service" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

Write-Host "` Setup complete!" -ForegroundColor Green
Write-Host "`nEndpoints:" -ForegroundColor Cyan
Write-Host "  Main:  http://localhost:8080/version" -ForegroundColor White
Write-Host "  Blue:  http://localhost:8081/version" -ForegroundColor Blue
Write-Host "  Green: http://localhost:8082/version" -ForegroundColor Green
