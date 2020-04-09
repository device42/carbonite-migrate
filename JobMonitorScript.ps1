# Target server and credentials variables

Try {
    # Import 'Set-D42DeviceStatus' script
    Import-Module -Name D:\development\carbonite-migrate\SetDeviceStatus.ps1 -Force

    # Read the Migrations.csv file     
    # $migrationPath = Read-Host -Prompt 'Please enter the location of the Migrations.csv file (Enter for default "C:\migrations\Migrations.csv"): '    
    # if (!$migrationPath) {
    #     $migrationPath = 'C:\migrations\Migrations.csv'
    # }
    $migrationPath = 'C:\migrations\Migrations.csv'
    $newstreamreader = New-Object System.IO.StreamReader("$migrationPath")
    $newstreamreader.ReadLine()     # skip the header
    $credentials = $newstreamreader.ReadLine().Split(",")

    # Set credentials
    $device_name = $credentials[0]
    $newstreamreader.Dispose()

    $DtTargetName = "10.90.12.2"
    $DtTargetUserName = "Administrator"
    $DtTargetPassword = Read-Host -AsSecureString -Prompt "Please enter the password for DTTarget"
    $D42Host ='https://192.168.56.100/'
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $DtTargetUserName, $DtTargetPassword

    # Import the Carbonite PowerShell module
    # This may be \Service\ or \Console\ depending on your installation
    Import-Module "C:\Program Files\Carbonite\Replication\Console\DoubleTake.PowerShell.dll"

    # Login to your target server
    $DtTarget = New-DtServer -Name $DtTargetName -UserName $DtTargetUserName -Password $Credential.GetNetworkCredential().Password

    $reportPath =  "C:\migrations\log.txt"

Do {
    # Get the jobs on the target and pass through to create a diagnostics file
    $currentJob = Get-DtJob -ServiceHost $DtTarget
    $jobStatus = Get-DtJobActionStatus -ServiceHost $DtTarget -JobId $currentJob.Id
    #$nl = [Environment]::NewLine

    $Time = Get-Date
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

    # Sleep 30 seconds
    Start-Sleep -Seconds 30
}
While ($currentJob.Status.HighLevelState -ne 'FailedOver')

    # Check to see that the failover has been successful and mark the migrated device as no longer active in D42
    if ($currentJob.Status.HighLevelState -eq 'FailedOver') {
        Write-Host [ Migrated $device_name has been deactivated! ]
        Set-D42DeviceStatus -baseURL $D42Host -method Post -username admin -password $DtTargetPassword -devName $device_name -inService no        
    }
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