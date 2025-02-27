using namespace System.Net

Function Invoke-AddChocoApp {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Endpoint.Application.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    Write-LogMessage -headers $Request.Headers -API $APINAME -message 'Accessed this API' -Sev 'Debug'

    Write-Host 'PowerShell HTTP trigger function processed a request.'
    $ChocoApp = $request.body
    $intuneBody = Get-Content 'AddChocoApp\choco.app.json' | ConvertFrom-Json
    $assignTo = $Request.body.AssignTo
    $intuneBody.description = $ChocoApp.description
    $intuneBody.displayName = $chocoapp.ApplicationName
    $intuneBody.installExperience.runAsAccount = if ($ChocoApp.InstallAsSystem) { 'system' } else { 'user' }
    $intuneBody.installExperience.deviceRestartBehavior = if ($ChocoApp.DisableRestart) { 'suppress' } else { 'allow' }
    $intuneBody.installCommandLine = "powershell.exe -executionpolicy bypass .\Install.ps1 -InstallChoco -Packagename $($chocoapp.PackageName)"
    if ($ChocoApp.customrepo) {
        $intuneBody.installCommandLine = $intuneBody.installCommandLine + " -CustomRepo $($chocoapp.CustomRepo)"
    }
    $intuneBody.UninstallCommandLine = "powershell.exe -executionpolicy bypass .\Uninstall.ps1 -Packagename $($chocoapp.PackageName)"
    $intunebody.detectionRules[0].path = "$($ENV:SystemDrive)\programdata\chocolatey\lib"
    $intunebody.detectionRules[0].fileOrFolderName = "$($chocoapp.PackageName)"

    $Tenants = $Request.body.selectedTenants.defaultDomainName
    $Results = foreach ($Tenant in $tenants) {
        try {
            $CompleteObject = [PSCustomObject]@{
                tenant             = $tenant
                Applicationname    = $ChocoApp.ApplicationName
                assignTo           = $assignTo
                InstallationIntent = $request.body.InstallationIntent
                IntuneBody         = $intunebody
            } | ConvertTo-Json -Depth 15
            $Table = Get-CippTable -tablename 'apps'
            $Table.Force = $true
            Add-CIPPAzDataTableEntity @Table -Entity @{
                JSON         = "$CompleteObject"
                RowKey       = "$((New-Guid).GUID)"
                PartitionKey = 'apps'
            }
            "Successfully added Choco App for $($Tenant) to queue."
            Write-LogMessage -headers $Request.Headers -API $APINAME -tenant $tenant -message "Successfully added Choco App $($intunebody.Displayname) to queue" -Sev 'Info'
        } catch {
            "Failed adding Choco App for $($Tenant) to queue"
            Write-LogMessage -headers $Request.Headers -API $APINAME -tenant $tenant -message "Failed to add Chocolatey Application $($intunebody.Displayname) to queue" -Sev 'Error'
        }
    }

    $body = [pscustomobject]@{'Results' = $results }

    # Associate values to output bindings by calling 'Push-OutputBinding'.
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = $body
        })
}
