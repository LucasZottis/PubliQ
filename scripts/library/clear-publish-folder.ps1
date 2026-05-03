param(
    [Parameter(Mandatory = $true)]
    [string]$PublishPath
)

Import-Module "$PSScriptRoot\..\..\modules\DevToolz.psm1" -Force

Write-Log "Limpando pasta de publicação: $PublishPath"
Remove-Folder -FolderPath $PublishPath
Write-Success "Pasta de publicação limpa com sucesso."
