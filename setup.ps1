Import-Module ".\modules\WriteFunctions.psm1"

function Set-PathExtPS1 {
    if (Confirm-PathExtPS1) {
        Write-Info ".PS1 já está no PATHEXT."
        retur;
    }

    Write-Log "Adicionando extensão .ps1"    
    $newPathext = "$env:PATHEXT;.PS1"
    
    # Persiste
    [Environment]::SetEnvironmentVariable("PATHEXT", $newPathext, "User")
    
    # Atualiza sessão atual
    $env:PATHEXT = $newPathext
    
    Write-Success "PATHEXT atualizado."
}

function Confirm-PathExtPS1 {
    Write-Log "Buscando extensões permitidas pelo PATH"
    Write-Info "Extensões atuais: $env:PATHEXT"
    
    if ($env:PATHEXT -notmatch "\.PS1") {
        return $false
    }

    return $true
}

function Confirm-PathExt($PublisherRoot) {
    # Atualiza PATH do usuário
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    
    if ($currentPath -notlike "*$PublisherRoot*") {
        return $false
    }

    Write-Info "PATH já contém o diretório do Publicador."
    return $true
}

function Set-PathExt {
    # Pasta onde o script está
    $publisherRoot = Split-Path -Parent $MyInvocation.MyCommand.Path 
    Write-Info "Diretório detectado: $publisherRoot"
    
    if (Confirm-PathExt -PublisherRoot $publisherRoot) {
        return
    }
    
    # Define variável opcional
    [Environment]::SetEnvironmentVariable(
        "Path",
        $publisherRoot,
        "User"
    )

    Write-Info "PATH atualizado com sucesso."
}

function Get-PowerShell7Path {
    $pwshCommand = Get-Command pwsh -ErrorAction SilentlyContinue

    if ($null -eq $pwshCommand) {
        return $null
    }

    try {
        $majorVersion = & $pwshCommand.Source -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.Major'
        if ([int]$majorVersion -ge 7) {
            return $pwshCommand.Source
        }
    }
    catch {
        Write-Warn "Não foi possível validar a versão do PowerShell: $_"
    }

    return $null
}

function Install-PowerShell7 {
    Write-Log "PowerShell 7 não encontrado. Iniciando instalação..."
    $wingetCommand = Get-Command winget -ErrorAction SilentlyContinue
    
    if ($wingetCommand) {
        Write-Log "Tentando instalar via winget..."

        & $wingetCommand.Source install --id Microsoft.PowerShell --exact --source winget --accept-source-agreements --accept-package-agreements --silent

        if ($LASTEXITCODE -eq 0) {
            Write-Success "PowerShell 7 instalado via winget."
            return $true
        }

        Write-Warn "Falha ao instalar via winget (código: $LASTEXITCODE). Tentando método alternativo..."
    }

    Write-Log "Baixando instalador mais recente do PowerShell 7..."
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
    $msiAsset = $release.assets | Where-Object { $_.name -match "win-x64\.msi$" } | Select-Object -First 1

    if (-not $msiAsset) {
        throw "Não foi possível localizar o instalador MSI win-x64 da versão mais recente do PowerShell."
    }

    $downloadPath = Join-Path $env:TEMP $msiAsset.name
    Invoke-WebRequest -Uri $msiAsset.browser_download_url -OutFile $downloadPath

    Write-Log "Executando instalador MSI..."
    Start-Process msiexec.exe -ArgumentList "/i `"$downloadPath`" /qn /norestart" -Wait -NoNewWindow

    if ($LASTEXITCODE -ne 0) {
        throw "Falha na instalação do MSI (código: $LASTEXITCODE)."
    }

    Write-Success "PowerShell 7 instalado via MSI."
    return $true
}

function Set-Ps1DefaultProgram {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PowerShellPath
    )

    Write-Log "Definindo PowerShell como aplicativo padrão para arquivos .ps1..."

    cmd /c 'assoc .ps1=Microsoft.PowerShellScript.1' | Out-Null
    cmd /c "ftype Microsoft.PowerShellScript.1=\"$PowerShellPath\" \"%1\" %*" | Out-Null

    Write-Success "Associação de arquivos .ps1 atualizada para o PowerShell."
}

function Start-Setup {
    $powerShellPath = Get-PowerShell7Path
    if (-not $powerShellPath) {
        Install-PowerShell7 | Out-Null
        $powerShellPath = Get-PowerShell7Path

        if (-not $powerShellPath) {
            throw "PowerShell 7 não foi encontrado após a tentativa de instalação."
        }
    }
    else {
        Write-Info "PowerShell 7 já está instalado em: $powerShellPath"
    }

    Set-Ps1DefaultProgram -PowerShellPath $powerShellPath    
    Set-PathExtPS1    
    Set-PathExt    
    
    Write-Success "Concluído."    
    Write-Host ""
    Write-Log "Pressione qualquer tecla para fechar..."
    [System.Console]::ReadKey($true) | Out-Null
}

try{
    Start-Setup
} catch {
    Write-Error $_
}
