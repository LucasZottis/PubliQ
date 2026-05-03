param(
    [Parameter(Mandatory = $true)]
    [string] $RepositoryPath,

    [Parameter(Mandatory = $true)]
    [string] $Version
)

# Obtém versão atual
$currentVersion = Get-CurrentVersion
        
# Chama seu método existente
$NewVersion = Resolve-NewVersion -CurrentVersion $currentVersion -bump $Version

if (-not $NewVersion) {
    throw "Falha ao gerar nova versão."
}

$publishSettings = Get-PublishSettings -Path "$RepositoryPath\publish.settings.json"

# Troca o branch se não estiver no branch padrão
if (-not (Test-IsCurrentBranch -branch $publishSettings.DefaultBranch)) {
    Write-Log "Trocando para o branch: $($publishSettings.DefaultBranch)"
    Switch-Branch -Branch $publishSettings.DefaultBranch
}

Resolve-Publish -PublishSettings $publishSettings -NewVersion $NewVersion