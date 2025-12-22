# Check Datadog Agent for received traces

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Datadog Agent Trace Status Check" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if agent is running
Write-Host "1. Checking Datadog Agent Status..." -ForegroundColor Yellow
$agentService = Get-Service -Name "datadogagent" -ErrorAction SilentlyContinue
if ($agentService) {
    if ($agentService.Status -eq "Running") {
        Write-Host "  [OK] Datadog Agent is running" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] Datadog Agent is stopped!" -ForegroundColor Red
        Write-Host "  Start it with: Start-Service datadogagent" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "  [ERROR] Datadog Agent not installed!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "2. Checking Agent Trace Stats..." -ForegroundColor Yellow
try {
    $agentStats = Invoke-RestMethod -Uri "http://127.0.0.1:8126/debug/stats" -UseBasicParsing
    Write-Host "  [OK] Agent is receiving trace data" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Trace Stats:" -ForegroundColor Cyan
    $agentStats | ConvertTo-Json -Depth 3 | Write-Host -ForegroundColor Gray
} catch {
    Write-Host "  [WARN] Could not fetch agent stats: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "3. Generating Test Traffic to Receiver..." -ForegroundColor Yellow
Write-Host "  Sending 5 requests..." -ForegroundColor Gray
for ($i = 1; $i -le 5; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8082/api/status/health" -UseBasicParsing
        Write-Host "  Request $i`: HTTP $($response.StatusCode)" -ForegroundColor Green
    } catch {
        Write-Host "  Request $i`: FAILED - $($_.Exception.Message)" -ForegroundColor Red
    }
    Start-Sleep -Milliseconds 500
}

Write-Host ""
Write-Host "4. Waiting for traces to be sent to agent (5 seconds)..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

Write-Host ""
Write-Host "5. Checking Agent Logs for Recent Activity..." -ForegroundColor Yellow
$agentLogPath = "C:\ProgramData\Datadog\logs\agent.log"
if (Test-Path $agentLogPath) {
    Write-Host "  Latest agent log entries:" -ForegroundColor Gray
    Get-Content $agentLogPath -Tail 20 | Write-Host -ForegroundColor Gray
} else {
    Write-Host "  [WARN] Agent log not found at $agentLogPath" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Check Datadog APM UI for services:" -ForegroundColor White
Write-Host "   https://app.datadoghq.com/apm/services" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. Look for these service names:" -ForegroundColor White
Write-Host "   - receiverwebapp (or ReceiverWebApp)" -ForegroundColor Gray
Write-Host "   - senderwebapp (or SenderWebApp)" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Set time range to 'Past 15 minutes'" -ForegroundColor White
Write-Host ""
Write-Host "4. If still not visible, check:" -ForegroundColor White
Write-Host "   - Datadog Agent config: C:\ProgramData\Datadog\datadog.yaml" -ForegroundColor Gray
Write-Host "   - Verify API key is correct in config" -ForegroundColor Gray
Write-Host "   - Check agent status: & 'C:\Program Files\Datadog\Datadog Agent\bin\agent.exe' status" -ForegroundColor Gray
Write-Host ""

