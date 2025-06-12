# Deploy Windows Runner Scale Set for ARC
# This script helps deploy and validate the Windows runner scale set configuration

param(
    [string]$Namespace = "arc-runners-win",
    [string]$ReleaseName = "arc-runner-set-win",
    [switch]$DryRun,
    [switch]$Validate,
    [switch]$Uninstall
)

Write-Host "ARC Windows Runner Scale Set Deployment Script" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green

# Function to check prerequisites
function Test-Prerequisites {
    Write-Host "`nChecking prerequisites..." -ForegroundColor Yellow
    
    # Check if helm is installed
    try {
        $helmVersion = helm version --short 2>$null
        Write-Host "✅ Helm is installed: $helmVersion" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Helm is not installed or not in PATH" -ForegroundColor Red
        return $false
    }
    
    # Check if kubectl is installed
    try {
        $kubectlVersion = kubectl version --client --short 2>$null
        Write-Host "✅ kubectl is installed: $kubectlVersion" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ kubectl is not installed or not in PATH" -ForegroundColor Red
        return $false
    }
    
    # Check if connected to cluster
    try {
        $currentContext = kubectl config current-context 2>$null
        Write-Host "✅ Connected to Kubernetes cluster: $currentContext" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Not connected to a Kubernetes cluster" -ForegroundColor Red
        return $false
    }
    
    return $true
}

# Function to validate configuration
function Test-Configuration {
    Write-Host "`nValidating configuration..." -ForegroundColor Yellow
    
    $configFile = "runner-scale-set-win.yaml"
    if (-not (Test-Path $configFile)) {
        Write-Host "❌ Configuration file not found: $configFile" -ForegroundColor Red
        return $false
    }
    
    Write-Host "✅ Configuration file found: $configFile" -ForegroundColor Green
    
    # Check if namespace exists
    try {
        kubectl get namespace $Namespace 2>$null | Out-Null
        Write-Host "✅ Namespace exists: $Namespace" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠️  Namespace does not exist: $Namespace (will be created)" -ForegroundColor Yellow
    }
    
    # Check if secret exists
    try {
        kubectl get secret arc-win-secret -n $Namespace 2>$null | Out-Null
        Write-Host "✅ GitHub authentication secret exists: arc-win-secret" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ GitHub authentication secret not found: arc-win-secret" -ForegroundColor Red
        Write-Host "   Create it with: kubectl create secret generic arc-win-secret -n $Namespace --from-literal=github_token='your_pat_token'" -ForegroundColor Yellow
        return $false
    }
    
    # Check if ACR secret exists
    try {
        kubectl get secret acr-secret -n $Namespace 2>$null | Out-Null
        Write-Host "✅ ACR authentication secret exists: acr-secret" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ ACR authentication secret not found: acr-secret" -ForegroundColor Red
        Write-Host "   Create it with: kubectl create secret docker-registry acr-secret -n $Namespace --docker-server=gharcacr1.azurecr.io --docker-username=<username> --docker-password=<password>" -ForegroundColor Yellow
        return $false
    }
    
    return $true
}

# Function to check if ARC controller is running
function Test-ARCController {
    Write-Host "`nChecking ARC controller..." -ForegroundColor Yellow
    
    try {
        $controllerPods = kubectl get pods -n arc-systems-win -l app.kubernetes.io/name=gha-rs-controller 2>$null
        if ($controllerPods) {
            Write-Host "✅ ARC controller is running in arc-systems-win namespace" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "❌ ARC controller not found in arc-systems-win namespace" -ForegroundColor Red
            Write-Host "   Install ARC controller first with the controller Helm chart" -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-Host "❌ ARC controller not found in arc-systems-win namespace" -ForegroundColor Red
        Write-Host "   Install ARC controller first with the controller Helm chart" -ForegroundColor Yellow
        return $false
    }
}

# Function to deploy the runner scale set
function Deploy-RunnerScaleSet {
    Write-Host "`nDeploying Windows Runner Scale Set..." -ForegroundColor Yellow
    
    $helmCommand = @(
        "helm", "install", $ReleaseName,
        "--namespace", $Namespace,
        "--create-namespace",
        "-f", "runner-scale-set-win.yaml",
        "oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set"
    )
    
    if ($DryRun) {
        $helmCommand += "--dry-run"
        Write-Host "🔍 Dry run mode - no changes will be made" -ForegroundColor Cyan
    }
    
    Write-Host "Running: $($helmCommand -join ' ')" -ForegroundColor Cyan
    
    try {
        & $helmCommand[0] $helmCommand[1..($helmCommand.Length-1)]
        if ($LASTEXITCODE -eq 0) {
            if (-not $DryRun) {
                Write-Host "✅ Windows Runner Scale Set deployed successfully!" -ForegroundColor Green
            } else {
                Write-Host "✅ Dry run completed successfully!" -ForegroundColor Green
            }
            return $true
        } else {
            Write-Host "❌ Deployment failed with exit code: $LASTEXITCODE" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "❌ Deployment failed: $_" -ForegroundColor Red
        return $false
    }
}

# Function to uninstall the runner scale set
function Uninstall-RunnerScaleSet {
    Write-Host "`nUninstalling Windows Runner Scale Set..." -ForegroundColor Yellow
    
    try {
        helm uninstall $ReleaseName -n $Namespace
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Windows Runner Scale Set uninstalled successfully!" -ForegroundColor Green
        } else {
            Write-Host "❌ Uninstall failed with exit code: $LASTEXITCODE" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "❌ Uninstall failed: $_" -ForegroundColor Red
    }
}

# Function to show deployment status
function Show-Status {
    Write-Host "`nChecking deployment status..." -ForegroundColor Yellow
    
    Write-Host "`nHelm releases:" -ForegroundColor Cyan
    helm list -n $Namespace
    
    Write-Host "`nPods in namespace:" -ForegroundColor Cyan
    kubectl get pods -n $Namespace
    
    Write-Host "`nAutoscaling runner sets:" -ForegroundColor Cyan
    kubectl get autoscalingrunnerset -n $Namespace
    
    Write-Host "`nRunner scale set events:" -ForegroundColor Cyan
    kubectl get events -n $Namespace --sort-by='.lastTimestamp' | tail -10
}

# Main execution
try {
    Set-Location $PSScriptRoot
    
    if ($Uninstall) {
        Uninstall-RunnerScaleSet
        exit
    }
    
    if (-not (Test-Prerequisites)) {
        Write-Host "`n❌ Prerequisites check failed. Please install missing tools." -ForegroundColor Red
        exit 1
    }
    
    if (-not (Test-ARCController)) {
        Write-Host "`n❌ ARC controller check failed. Please install ARC controller first." -ForegroundColor Red
        exit 1
    }
    
    if ($Validate) {
        $valid = Test-Configuration
        if ($valid) {
            Write-Host "`n✅ Configuration validation passed!" -ForegroundColor Green
        } else {
            Write-Host "`n❌ Configuration validation failed!" -ForegroundColor Red
            exit 1
        }
        exit 0
    }
    
    if (-not (Test-Configuration)) {
        Write-Host "`n❌ Configuration validation failed. Please fix the issues above." -ForegroundColor Red
        exit 1
    }
    
    if (Deploy-RunnerScaleSet) {
        Start-Sleep -Seconds 5
        Show-Status
        
        Write-Host "`n🎉 Deployment completed!" -ForegroundColor Green
        Write-Host "`nNext steps:" -ForegroundColor Yellow
        Write-Host "1. Monitor the pods: kubectl get pods -n $Namespace -w" -ForegroundColor White
        Write-Host "2. Check logs: kubectl logs -n $Namespace -l app.kubernetes.io/name=gha-runner-scale-set" -ForegroundColor White
        Write-Host "3. Test with a workflow that uses 'runs-on: $ReleaseName'" -ForegroundColor White
    }
}
catch {
    Write-Host "`n❌ Script execution failed: $_" -ForegroundColor Red
    exit 1
}
