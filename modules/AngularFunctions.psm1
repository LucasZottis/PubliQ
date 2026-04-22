function Update-VersionInPackageJson {
    param(
        [Parameter(Mandatory)]
        [string]$NewVersion,
        [Parameter(Mandatory)]
        [string]$Path
    )

    $packageJsonPath = Join-Path $Path "package.json"

    if (-not (Test-Path $packageJsonPath)) {
        throw "package.json não encontrado em: $Path"
    }

    Write-Log "Atualizando versão em ""package.json"""
    $json = Get-Content $packageJsonPath -Raw | ConvertFrom-Json
    $json.version = $NewVersion
    $json | ConvertTo-Json -Depth 100 | Set-Content $packageJsonPath -Encoding UTF8
}

function Start-AngularTests {
    param(
        [Parameter(Mandatory)]
        [string]$ProjectPath
    )

    Push-Location $ProjectPath
    try {
        $output = & ng test --watch=false 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Falha nos testes"
            Write-Host $output
            throw "Testes Angular falharam. Release abortado."
        }
    }
    finally {
        Pop-Location
    }
}

function Start-AngularBuild {
    param(
        [Parameter(Mandatory)]
        [string]$ProjectPath,
        [Parameter(Mandatory)]
        [string]$OutputPath,
        [string[]]$Arguments = @()
    )

    Write-Log "Executando ng build"

    Push-Location $ProjectPath
    try {
        $output = & ng build --output-path $OutputPath @Arguments 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Error "❌ Falha no build:"
            Write-Host $output
            exit 1
        }
    }
    finally {
        Pop-Location
    }
}

function Resolve-AngularCliArguments {
    param(
        [hashtable]$Arguments = @{}
    )

    if (-not $Arguments -or $Arguments.Count -eq 0) {
        return @()
    }

    $cliArgs = [System.Collections.Generic.List[string]]::new()

    foreach ($key in $Arguments.Keys) {
        $value = $Arguments[$key]

        if ($value -is [bool]) {
            if ($value) {
                $cliArgs.Add("--$key")
            }
        }
        else {
            $cliArgs.Add("--$key")
            $cliArgs.Add("$value")
        }
    }

    return $cliArgs.ToArray()
}

Export-ModuleMember -Function *
