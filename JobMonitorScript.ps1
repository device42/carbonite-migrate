# Target server and credentials variables

Try {
    # Import the Carbonite PowerShell module
    # This may be \Service\ or \Console\ depending on your installation
    Import-Module "C:\Program Files\Carbonite\Replication\Console\DoubleTake.PowerShell.dll"
    # Import 'Set-D42DeviceStatus' script
    Import-Module -Name ($PSScriptRoot + "\SetDeviceStatus.ps1") -Force

    $devInfoPath = $PSScriptRoot + "\vmName.txt"
    $reportPath = $PSScriptRoot + "\log.txt"
    [System.Collections.ArrayList]$jobs = Get-Content -Path $devInfoPath

    $DtTargetName = Read-Host -Prompt 'Please enter the DoubleTake target IP'    
    if (!$DtTargetName) {
        $DtTargetName = "10.90.12.2"
    }
    $DtTargetUserName = Read-Host -Prompt 'Please enter the DoubleTake target user name'    
    if (!$DtTargetUserName) {
        $DtTargetUserName = "Administrator"
    }    
    $DtTargetPassword = Read-Host -AsSecureString -Prompt "Please enter the DoubleTake target password"
    $D42Host = Read-Host -Prompt 'Please enter the Device42 URL'    
    if (!$D42Host) {
        $D42Host = "https://192.168.56.100/"
    }   
    else {
        $D42Host = "https://" + $D42Host + "/"
    }
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $DtTargetUserName, $DtTargetPassword
    # Login to your target server
    $DtTarget = New-DtServer -Name $DtTargetName -UserName $DtTargetUserName -Password $Credential.GetNetworkCredential().Password

    # Create the background job
    $async_job = {
        param ($DtTarget, $reportPath)

        # jobs to be removed from main list upon completion
        $finishedJobs = $jobs.Clone()
        Do {
            # Process each jobid in the jobs file
            
            Foreach ($job in $jobs) {
                $jobInfo = $job.Split(",")
                # Set credentials
                # Get the jobs on the target and pass through to create a diagnostics file
                $currentJob = Get-DtJob -ServiceHost $DtTarget -JobId $jobInfo[2]
                $jobStatus = Get-DtJobActionStatus -ServiceHost $DtTarget -JobId $jobInfo[2]            

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
                    $finishedJobs.Remove($job)
                    # Check to see that the failover has been successful and mark the migrated device as no longer active in D42
                    Write-Host [ Migrated $jobInfo[0] has been deactivated! ]
                    Set-D42DeviceStatus -baseURL $D42Host -method Post -username admin -password $DtTargetPassword -devInfo $jobInfo -inService no        
                }
            }
            $jobs = $finishedJobs.Clone()
            # Sleep 30 seconds
            Start-Sleep -Seconds 30
        }
        While ($jobs.Count -gt 0)
    }

    # Launch a background job for each device
    # Set-PSBreakpoint -Script @($PSScriptRoot + "\JobMonitorScript.ps1") -Line 45
    #$j = Start-Job -ScriptBlock $async_job -ArgumentList $jobInfo, $DtTarget, $reportPath
    Invoke-Command -ScriptBlock $async_job -ArgumentList $DtTarget, $reportPath 

}
Catch {
    $FailedItem = $_.Exception.ItemName
    $ErrorMessage = "ERROR: " + $_.Exception.Message + $FailedItem
    Write-Error -Exception $_.Exception -Message "An error has occurred: 
    $_.Exception.ItemName"
    Add-Content -Path $reportPath -Value $ErrorMessage
}
Finally {
    # Close the connections for the server object
    Disconnect-DtServer -ServiceHost $DtTarget
}