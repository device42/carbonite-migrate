# Target server and credentials variables
add-type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
$AllProtocols = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'
[System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

Try {
    # Import the Carbonite PowerShell module
    # This may be \Service\ or \Console\ depending on your installation
    Import-Module "C:\Program Files\Carbonite\Replication\Console\DoubleTake.PowerShell.dll"
    # Import 'Set-D42DeviceStatus' script
    Import-Module -Name ($PSScriptRoot + "\SetDeviceStatus.ps1") -Force

    $devInfoPath = $PSScriptRoot + "\vmName.txt"    
    $jobs = New-Object -TypeName System.Collections.ArrayList
    foreach ($line in (Get-Content -Path $devInfoPath)) {
        if ($line -ne '\n') {
            $jobs.Add($line)
        }
    }
    #  = Get-Content -Path $devInfoPath

    $DtTargetName = Read-Host -Prompt 'Please enter the DoubleTake target IP'    
    if (!$DtTargetName) {
        $DtTargetName = "10.90.12.2"
        #$DtTargetName = "10.90.11.22"
    }
    $DtTargetUserName = Read-Host -Prompt 'Please enter the DoubleTake target user name'    
    if (!$DtTargetUserName) {
        $DtTargetUserName = "Administrator"
    }    
    $DtTargetPassword = Read-Host -AsSecureString -Prompt "Please enter the DoubleTake target password"
    $D42Host = Read-Host -Prompt 'Please enter the Device42 URL (without http:// or https:// prefixes)'    
    if (!$D42Host) {
        $D42Host = "https://192.168.56.100"
    }   
    else {
        if ($D42Host -and $D42Host -notmatch '(^https:\/\/).+') {
                $D42Host = "https://" + $D42Host          
        }
    }
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $DtTargetUserName, $DtTargetPassword
    # Login to your target server
    $DtTarget = New-DtServer -Name $DtTargetName -UserName $DtTargetUserName -Password $Credential.GetNetworkCredential().Password

    # Process jobs
    $job = {
        param ($DtTarget)

        # jobs to be removed from main list upon completion
        $unfinishedJobs = $jobs.Clone()
        Do {
            # Process each jobid in the jobs file
            
            Foreach ($job in $jobs) {
                $jobInfo = $job.Split(",")
                # Set credentials
                # Get the jobs on the target and pass through to create a diagnostics file
                $currentJob = Get-DtJob -ServiceHost $DtTarget -JobId $jobInfo[2]
                $jobStatus = Get-DtJobActionStatus -ServiceHost $DtTarget -JobId $jobInfo[2]
                $reportPath = $PSScriptRoot + "\" + $jobInfo[0] + ".log"

                $Time = Get-Date
                # Wait-Debugger
                $jobStatus =     
                "=============================================================================================================
                Time                 : $Time
                Job ID               : $($currentJob.Id)
                JobType              : $($currentJob.JobType)
                SourceHostUri        : $($currentJob.SourceHostUri)
                Health               : $($currentJob.Status.Health)
                Status               : $($currentJob.Status.HighLevelState)
                TargetState          : $($currentJob.Status.TargetState)
                MessageId            : $($jobStatus.MessageId)
                TimeStamp            : $($jobStatus.TimeStamp)
                Status               : $($jobStatus.Status)"
        
                # | Save-DtJobDiagnostics -ServiceHost $DtTarget
                Add-Content -Path $reportPath -Value $jobStatus    
                # Write to console
                Write-Host $jobStatus     
                
                if ($currentJob.Status.HighLevelState -eq 'FailedOver') {
                    $unfinishedJobs.Remove($job)
                    # Check to see that the failover has been successful and mark the migrated device as no longer active in D42
                    Add-Content -Path $reportPath -Value "[Migrated $($jobInfo[0]) has been deactivated!]"
                    Write-Host [Device $jobInfo[0] has been migrated and deactivated on D42!]
                    
                    Set-D42DeviceStatus -baseURL $D42Host -method Post -username admin -password $DtTargetPassword -devInfo $jobInfo -inService no -reportPath $reportPath
                }
            }
            $jobs = $unfinishedJobs.Clone()
            # Sleep 30 seconds
            Start-Sleep -Seconds 30
        }
        While ($jobs.Count -gt 0)
    }

    # Launch a background job for each device    
    Invoke-Command -ScriptBlock $job -ArgumentList $DtTarget

}
Catch {
    $FailedItem = $_.Exception.ItemName
    $ErrorMessage = "ERROR: " + $_.Exception.Message + $FailedItem
    Write-Error -Exception $_.Exception -Message "An error has occurred: 
    $_.Exception.ItemName"
    Add-Content -Path $reportPath -Value $ErrorMessage
}
Finally {
    if ($DtTarget) {
        # Close the connections for the server object
        Disconnect-DtServer -ServiceHost $DtTarget    
    }
}