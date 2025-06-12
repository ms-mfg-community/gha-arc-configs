FROM mcr.microsoft.com/windows/servercore:ltsc2022 AS build

# Replace value with the latest runner release version
# source: https://github.com/actions/runner/releases
# Latest stable: 2.324.0
ARG RUNNER_VERSION="2.324.0"
ARG RUNNER_ARCH="x64"
# Replace value with the latest runner-container-hooks release version
# source: https://github.com/actions/runner-container-hooks/releases
# Latest: 0.7.0
ARG RUNNER_CONTAINER_HOOKS_VERSION="0.7.0"

# Windows environment variables
ENV RUNNER_MANUALLY_TRAP_SIG=1
ENV ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT=1
ENV GIT_TERMINAL_PROMPT=0
ENV GIT_TRACE=0

# Install PowerShell and necessary tools using Chocolatey
RUN powershell -Command \
    "Set-ExecutionPolicy Bypass -Scope Process -Force; \
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; \
    Write-Host 'Installing Chocolatey...'; \
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')); \
    Write-Host 'Installing basic tools...'; \
    choco install -y curl 7zip git --no-cache; \
    New-Item -ItemType Directory -Path 'C:\\temp' -Force; \
    Write-Host 'Basic tools installation completed'"

# Install Visual Studio 2022 Build Tools with required components for WDK
RUN powershell -Command \
    "Write-Host 'Downloading and installing Visual Studio Build Tools 2022...'; \
    $vsUrl = 'https://aka.ms/vs/17/release/vs_buildtools.exe'; \
    Invoke-WebRequest -Uri $vsUrl -OutFile vs_buildtools.exe; \
    $args = '--quiet', '--wait', '--add', 'Microsoft.VisualStudio.Workload.VCTools', '--add', 'Microsoft.VisualStudio.Workload.MSBuildTools', '--add', 'Microsoft.VisualStudio.Component.Windows11SDK.22621', '--add', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64', '--add', 'Microsoft.VisualStudio.Component.VC.Redist.14.Latest', '--add', 'Microsoft.VisualStudio.Component.VC.ATL', '--add', 'Microsoft.VisualStudio.Component.VC.ATLMFC'; \
    Start-Process -FilePath 'vs_buildtools.exe' -ArgumentList $args -Wait; \
    Remove-Item vs_buildtools.exe -Force; \
    Write-Host 'Cleaning up VS installer cache...'; \
    Remove-Item 'C:\\ProgramData\\Microsoft\\VisualStudio\\Packages\\_Instances' -Recurse -Force -ErrorAction SilentlyContinue; \
    Write-Host 'Visual Studio Build Tools installation completed'"

# Install Windows SDK and WDK
RUN powershell -Command \
    "Write-Host 'Installing Windows SDK...'; \
    $sdkUrl = 'https://go.microsoft.com/fwlink/?linkid=2196241'; \
    Invoke-WebRequest -Uri $sdkUrl -OutFile 'C:\\temp\\winsdksetup.exe'; \
    Start-Process -FilePath 'C:\\temp\\winsdksetup.exe' -ArgumentList '/quiet' -Wait; \
    Remove-Item 'C:\\temp\\winsdksetup.exe' -Force; \
    Write-Host 'Installing Windows WDK...'; \
    $wdkUrl = 'https://go.microsoft.com/fwlink/?linkid=2307500'; \
    Invoke-WebRequest -Uri $wdkUrl -OutFile 'C:\\temp\\wdksetup.exe'; \
    Start-Process -FilePath 'C:\\temp\\wdksetup.exe' -ArgumentList '/quiet' -Wait; \
    Remove-Item 'C:\\temp\\wdksetup.exe' -Force; \
    Write-Host 'Cleaning up temp directory...'; \
    Remove-Item 'C:\\temp\\*' -Recurse -Force -ErrorAction SilentlyContinue; \
    Write-Host 'SDK and WDK installation completed'"

# Set environment variables for development tools
ENV WindowsSDKDir="C:\\Program Files (x86)\\Windows Kits\\10\\"
ENV WDKDir="C:\\Program Files (x86)\\Windows Kits\\10\\"
ENV VSINSTALLDIR="C:\\Program Files (x86)\\Microsoft Visual Studio\\2022\\BuildTools\\"
ENV PATH="C:\\Windows\\System32\\WindowsPowerShell\\v1.0;C:\\Program Files\\Git\\bin;C:\\Program Files (x86)\\Microsoft Visual Studio\\2022\\BuildTools\\MSBuild\\Current\\Bin;C:\\Program Files (x86)\\Windows Kits\\10\\bin\\10.0.26100.0\\x64;${PATH}"

# Set Git configuration to handle Windows paths properly
RUN C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command \
    git config --system core.longpaths true; \
    git config --system core.autocrlf true

# Create runner user (Windows equivalent of adduser)
# Note: Windows containers handle user management differently
RUN C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command \
    if (-not (Get-LocalUser -Name \"runner\" -ErrorAction SilentlyContinue)) { \
        C:\Windows\System32\net.exe user runner /add /passwordreq:no /expires:never; \
        Write-Host \"User runner created successfully\"; \
    } else { \
        Write-Host \"User runner already exists\"; \
    }; \
    \
    try { \
        C:\Windows\System32\net.exe localgroup \"Users\" runner /add; \
        Write-Host \"Added runner to Users group\"; \
    } catch { \
        if ($_.Exception.Message -match \"already a member\") { \
            Write-Host \"User runner is already a member of Users group\"; \
        } else { \
            throw $_; \
        } \
    }; \
    \
    try { \
        C:\Windows\System32\net.exe localgroup \"Administrators\" runner /add; \
        Write-Host \"Added runner to Administrators group\"; \
    } catch { \
        if ($_.Exception.Message -match \"already a member\") { \
            Write-Host \"User runner is already a member of Administrators group\"; \
        } else { \
            throw $_; \
        } \
    }

# Create a folder under the drive root
RUN C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command \
    mkdir \actions-runner ; cd \actions-runner

# Set working directory (Windows path)
WORKDIR C:/actions-runner

# Download and extract GitHub Actions runner for Windows
# Note: Using Windows binary instead of Linux
RUN C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command \
    $url = \"https://github.com/actions/runner/releases/download/v$env:RUNNER_VERSION/actions-runner-win-$env:RUNNER_ARCH-$env:RUNNER_VERSION.zip\"; \
    Write-Host \"Downloading runner from: $url\"; \
    Invoke-WebRequest -Uri $url -OutFile runner.zip; \
    Expand-Archive -Path runner.zip -DestinationPath .; \
    Remove-Item runner.zip

# Download and extract runner container hooks
RUN C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command \
    $url = \"https://github.com/actions/runner-container-hooks/releases/download/v$env:RUNNER_CONTAINER_HOOKS_VERSION/actions-runner-hooks-k8s-$env:RUNNER_CONTAINER_HOOKS_VERSION.zip\"; \
    Write-Host \"Downloading container hooks from: $url\"; \
    Invoke-WebRequest -Uri $url -OutFile runner-container-hooks.zip; \
    New-Item -ItemType Directory -Path k8s -Force; \
    Expand-Archive -Path runner-container-hooks.zip -DestinationPath k8s; \
    Remove-Item runner-container-hooks.zip

# Set permissions for the runner user (Windows equivalent of chown)
RUN C:\Windows\System32\icacls.exe C:/actions-runner /grant runner:F /T

# Create the PowerShell run script for ARC compatibility
RUN C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command \
    "New-Item -Path 'C:\\actions-runner\\run.ps1' -ItemType File -Force; \
    Add-Content -Path 'C:\\actions-runner\\run.ps1' -Value 'Write-Host \"Starting ARC Windows Runner...\"'; \
    Add-Content -Path 'C:\\actions-runner\\run.ps1' -Value 'Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force'; \
    Add-Content -Path 'C:\\actions-runner\\run.ps1' -Value 'Set-Location C:\\actions-runner'; \
    Add-Content -Path 'C:\\actions-runner\\run.ps1' -Value 'try {'; \
    Add-Content -Path 'C:\\actions-runner\\run.ps1' -Value '    & .\\run.cmd'; \
    Add-Content -Path 'C:\\actions-runner\\run.ps1' -Value '} catch {'; \
    Add-Content -Path 'C:\\actions-runner\\run.ps1' -Value '    Write-Host \"Runner execution failed: `$_\"'; \
    Add-Content -Path 'C:\\actions-runner\\run.ps1' -Value '    exit 1'; \
    Add-Content -Path 'C:\\actions-runner\\run.ps1' -Value '}'"

# Verify the run.ps1 script was created correctly and set proper permissions
RUN C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command \
    "if (Test-Path 'C:\\actions-runner\\run.ps1') { \
        Write-Host 'run.ps1 created successfully with content:'; \
        Get-Content 'C:\\actions-runner\\run.ps1' | ForEach-Object { Write-Host \"  $_\" }; \
        C:\Windows\System32\icacls.exe 'C:\\actions-runner\\run.ps1' /grant runner:F; \
        Write-Host 'Permissions set for run.ps1'; \
    } else { \
        Write-Host 'ERROR: run.ps1 was not created'; \
        exit 1; \
    }"

# Verify run.cmd exists and set proper permissions
RUN C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command \
    "if (Test-Path 'C:\\actions-runner\\run.cmd') { \
        Write-Host 'run.cmd found'; \
        C:\Windows\System32\icacls.exe 'C:\\actions-runner\\run.cmd' /grant runner:F; \
        Write-Host 'Permissions set for run.cmd'; \
    } else { \
        Write-Host 'ERROR: run.cmd not found in actions-runner directory'; \
        Write-Host 'Directory contents:'; \
        Get-ChildItem 'C:\\actions-runner' | ForEach-Object { Write-Host \"  $($_.Name)\" }; \
        exit 1; \
    }"

# Set global PowerShell execution policy for the container
RUN C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope LocalMachine -Force

# Switch to runner user
USER runner
