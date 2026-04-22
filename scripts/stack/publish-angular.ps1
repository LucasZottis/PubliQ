param(
    [Parameter(Mandatory = $true)]
    [pscustomobject]$Project,

    [Parameter(Mandatory = $true)]
    [string]$NewVersion
)

try {
    Import-Module "$PSScriptRoot\..\..\modules\AngularFunctions.psm1" -Force
    Write-Title "Projeto: $($Project.Name)"

    $projectPath = (Resolve-Path $Project.Path).Path
    $outputPath = [System.IO.Path]::GetFullPath($Project.PublishPath)
    $arguments = Resolve-Arguments -Arguments $Project.Arguments

    $skipTests = $arguments.ContainsKey("SkipTests") -and [bool]$arguments["SkipTests"]
    $arguments.Remove("SkipTests") | Out-Null

    # Atualiza versão no package.json
    Write-Log "Atualizando versão nos projetos..."
    Update-VersionInPackageJson -NewVersion $NewVersion -Path $projectPath
    Write-Success "Projetos atualizados"

    # Executa testes
    if (-not $skipTests) {
        Write-Log "Executando testes..."
        Start-AngularTests -ProjectPath $projectPath
        Write-Success "Testes finalizados!"
    }
    else {
        Write-Warn "Testes ignorados conforme configuração."
    }

    # BEFORE
    if ($Project.Scripts -and $Project.Scripts.Before) {
        Write-Log "Iniciando execução dos scripts pré publicação do projeto..."
        Resolve-PublishScripts -Scripts $Project.Scripts.Before
        Write-Success "Scripts executados!"
    }

    $cliArguments = Resolve-AngularCliArguments -Arguments $arguments
    Start-AngularBuild -ProjectPath $projectPath -OutputPath $outputPath -Arguments $cliArguments

    # AFTER
    if ($Project.Scripts -and $Project.Scripts.After) {
        Write-Log "Iniciando execução dos scripts pós publicação do projeto..."
        Resolve-PublishScripts -Scripts $Project.Scripts.After
        Write-Success "Scripts executados!"
    }

    Write-Success "Publicação de ""$($Project.Name)"" finalizado!"
}
catch {
    Write-Error $_
    exit 1
}
