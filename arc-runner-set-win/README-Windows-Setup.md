# Windows Runner Scale Set Setup Guide

This guide helps you complete the setup of Windows runners with GitHub Actions Runner Controller (ARC).

## Overview

Your Windows runner scale set configuration includes:
- **Custom Windows runner image**: `gharcacr1.azurecr.io/actions-runner-windows:latest`
- **Node targeting**: Windows nodes with `agentpool: npwin`
- **Resource limits**: 4 CPU / 8GB RAM per runner
- **Authentication**: Using pre-defined Kubernetes secret `arc-win-secret`
- **Registry access**: Using `acr-secret` for Azure Container Registry

## Prerequisites

### 1. ARC Controller
Ensure the ARC controller is installed in your cluster:
```powershell
helm list -n arc-system
```

If not installed, install it first:
```powershell
helm install arc-controller `
  --namespace arc-system `
  --create-namespace `
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller
```

### 2. Kubernetes Secrets

#### GitHub Authentication Secret
Create the secret for GitHub authentication:
```powershell
# Using Personal Access Token (PAT)
kubectl create secret generic arc-win-secret `
  --namespace arc-runners `
  --from-literal=github_token='ghp_your_personal_access_token'

# OR using GitHub App (recommended for organizations)
kubectl create secret generic arc-win-secret `
  --namespace arc-runners `
  --from-literal=github_app_id='123456' `
  --from-literal=github_app_installation_id='654321' `
  --from-literal=github_app_private_key='-----BEGIN PRIVATE KEY-----...'
```

#### Azure Container Registry Secret
Create the secret for ACR access:
```powershell
kubectl create secret docker-registry acr-secret `
  --namespace arc-runners `
  --docker-server=gharcacr1.azurecr.io `
  --docker-username=<your-acr-username> `
  --docker-password=<your-acr-password>
```

### 3. Windows Runner Image

Build and push your Windows runner image:
```powershell
# Build the Windows runner image
docker build -t gharcacr1.azurecr.io/actions-runner-windows:latest .

# Push to your registry
docker push gharcacr1.azurecr.io/actions-runner-windows:latest
```

## Deployment Steps

### 1. Validate Configuration
```powershell
.\deploy-windows-runners.ps1 -Validate
```

### 2. Dry Run Deployment
```powershell
.\deploy-windows-runners.ps1 -DryRun
```

### 3. Deploy Windows Runners
```powershell
.\deploy-windows-runners.ps1
```

### 4. Monitor Deployment
```powershell
# Watch pods
kubectl get pods -n arc-runners -w

# Check runner scale set status
kubectl get autoscalingrunnerset -n arc-runners

# View logs
kubectl logs -n arc-runners -l app.kubernetes.io/name=gha-runner-scale-set
```

## Testing Your Windows Runners

Create a workflow in your GitHub repository to test the Windows runners:

```yaml
name: Test Windows Runners
on: [push, workflow_dispatch]

jobs:
  windows-test:
    runs-on: arc-runner-set-win  # This matches your runner scale set name
    steps:
      - uses: actions/checkout@v4
      
      - name: Test Windows Environment
        run: |
          Write-Host "Testing Windows runner..."
          Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion
          Write-Host "PowerShell version: $($PSVersionTable.PSVersion)"
          
      - name: Test Docker (if available)
        run: |
          try {
            docker --version
            Write-Host "Docker is available"
          } catch {
            Write-Host "Docker not available or not configured"
          }
```

## Configuration Details

### Key Windows-Specific Settings

1. **Container Command**: Uses PowerShell to start the runner
   ```yaml
   command: ["powershell.exe", "-File", "C:\\actions-runner\\run.ps1"]
   ```

2. **Docker Host**: Configured for Windows named pipes
   ```yaml
   env:
     - name: DOCKER_HOST
       value: "npipe:////./pipe/docker_engine"
   ```

3. **Volume Mounts**: Windows path format
   ```yaml
   volumeMounts:
     - name: work
       mountPath: C:\actions-runner\_work
   ```

4. **Security Context**: Windows-specific user settings
   ```yaml
   securityContext:
     windowsOptions:
       runAsUserName: "ContainerUser"
   ```

### Node Selection

The configuration targets Windows nodes with:
```yaml
nodeSelector:
  kubernetes.io/os: windows
  agentpool: npwin
```

Make sure your AKS cluster has Windows node pools with the `npwin` label.

### Listener Configuration

The listener runs on Linux nodes to manage Windows runners:
```yaml
listenerTemplate:
  spec:
    nodeSelector:
      kubernetes.io/os: linux
```

## Troubleshooting

### Common Issues

1. **Pods stuck in ImagePullBackOff**
   - Check ACR secret: `kubectl get secret acr-secret -n arc-runners`
   - Verify image exists: `docker pull gharcacr1.azurecr.io/actions-runner-windows:latest`

2. **Authentication failures**
   - Verify GitHub secret: `kubectl get secret arc-win-secret -n arc-runners`
   - Check token permissions (needs repo, workflow, admin:org scope)

3. **Pods not scheduling**
   - Check node selector: `kubectl get nodes -l kubernetes.io/os=windows`
   - Verify Windows node pool exists and is ready

4. **Runner not appearing in GitHub**
   - Check runner logs: `kubectl logs -n arc-runners -l app.kubernetes.io/component=runner`
   - Verify GitHub configuration URL in YAML

### Useful Commands

```powershell
# Get all resources in the namespace
kubectl get all -n arc-runners

# Describe autoscaling runner set
kubectl describe autoscalingrunnerset -n arc-runners

# Get events
kubectl get events -n arc-runners --sort-by='.lastTimestamp'

# Delete and redeploy
.\deploy-windows-runners.ps1 -Uninstall
.\deploy-windows-runners.ps1
```

## Security Considerations

1. **Use GitHub Apps** instead of PATs for better security
2. **Limit runner access** using runner groups in GitHub
3. **Use resource limits** to prevent resource exhaustion
4. **Keep images updated** with latest security patches
5. **Monitor runner usage** for suspicious activity

## Next Steps

1. **Scale Testing**: Test with multiple concurrent jobs
2. **Custom Images**: Add tools and dependencies your workflows need
3. **Monitoring**: Set up metrics and alerts for runner health
4. **Backup**: Document your configuration for disaster recovery
5. **Updates**: Plan for updating ARC and runner images

## Support Resources

- [ARC Documentation](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller)
- [ARC Troubleshooting](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller/troubleshooting-actions-runner-controller-errors)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
