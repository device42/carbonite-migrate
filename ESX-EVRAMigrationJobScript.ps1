# Server to ESX migration job
Try {
    # Source server and credentials

    # Read the Migrations.csv file 
    $migrationPath = Read-Host -Prompt 'Please enter the location of the migration CSV file (Without quotes like C:\migrations\carbonite-migration.csv)'
    if (!$migrationPath) {
        # Set the path for the downloaded migrations file here...
        $migrationPath = 'C:\migrations\carbonite-migration.csv'
    }
    $newstreamreader = New-Object System.IO.StreamReader("$migrationPath")
    $newstreamreader.ReadLine()     # skip the header
    $credentials = $newstreamreader.ReadLine().Split(",")

    # Set credentials
    $device_name = $credentials[0]
    $source_ip = $credentials[1]
    $source_user = $credentials[2]
    $source_pw = ConvertTo-SecureString -String $credentials[3] -AsPlainText -Force 
    $newstreamreader.Dispose()

    $DtSourceName = $source_ip
    $DtSourceUserName = $source_user
    $DtSourcePassword = $source_pw

    $reportPath = "C:\migrations\error.log"

    # Target server and credentials (carbonite-template)
    $DtTargetName = Read-Host -Prompt 'Please enter the target IP for the migration'
    if (!$DtTargetName) {
        $DtTargetName = '10.90.12.2'
    }
    $DtTargetUserName = Read-Host -Prompt 'Please enter the target user name'
    if (!$DtTargetUserName) {
        $DtTargetUserName = "Administrator"
    }    
    
    $DtTargetPassword = Read-Host -AsSecureString -Prompt "Please enter the target user password"

    $TargetCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $DtTargetUserName, $DtTargetPassword
    $SourceCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $credentials[2], $DtSourcePassword

    # ESX host and credentials

    # If you are using vCenter, specify your vCenter.

    # Only specify an ESX host if you are using ESX standalone.
    $DtHostName = Read-Host -Prompt 'Please enter the host IP for the migration'
    if (!$DtHostName) {
        $DtHostName = "10.90.0.12"    
    }
    $DtHostUserName = Read-Host -Prompt 'Please enter the host user name'
    if (!$DtHostUserName) {
        $DtHostUserName = "root"
    }
    
    $DtHostPassword = Read-Host -AsSecureString -Prompt "Please enter the host user password"

    $HostCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $DtHostUserName, $DtHostPassword

    # Type of workload you will be protecting and type of job you will be creating
    $DtWorkloadType = Read-Host -Prompt 'Please enter the type of job you will be creating [default = VraMove]'
    if (!$DtWorkloadType) {
        $DtWorkloadType = "VraMove"
    }
    $DtJobType = $DtWorkloadType

    # Import the Carbonite PowerShell module
    # This may be \Service\ or \Console\ depending on your installation
    Import-Module "C:\Program Files\Carbonite\Replication\Console\DoubleTake.PowerShell.dll"

    # Create source and target objects
    $DtSource = New-DtServer -Name $DtSourceName -UserName $DtSourceUserName -Password $SourceCredential.GetNetworkCredential().Password
    $DtTarget = New-DtServer -Name $DtTargetName -UserName $DtTargetUserName -Password $TargetCredential.GetNetworkCredential().Password

    # Create ESX host appliance object
    # If you are using vCenter, specify your vCenter.
    # Only specify an ESX host if you are using ESX standalone.
    # TODO: Try disabling this setting, as it might be redundant.
    $VimTarget = New-DtServer -Name $DtHostName -Username $DtHostUserName -Password $HostCredential.GetNetworkCredential().Password -Role TargetVimServer

    $OtherServers = @($VimTarget)

    # Create a workload
    $DtWorkloadGUID = New-DtWorkload -ServiceHost $DtSource -WorkloadTypeName $DtWorkloadType

    # This workload, by default, selects all volumes for protection
    # If desired, exclude any volumes from protection, however, be careful
    # when excluding data as it may compromise the integrity of your installed applications
    # Uncomment and use the following line, substituting G:\for the volume you want to exclude
    # Repeat the line to exclude multiple volumes
    # Set-DtLogicalItemSelection -ServiceHost $DtSource -WorkloadId $DtWorkloadGuid -LogicalPath "G:\" -Unselect

    # Get the workload definition including the workload and logical items
    $DtWorkload = Get-DtWorkload -ServiceHost $DtSource -WorkloadId $DtWorkloadGUID

    # Get the default job options that will be used to create the job
    $DtJobOptions = Get-DtRecommendedJobOptions -ServiceHost $DtTarget -Source $DtSource -JobType $DtJobType -Workload $DtWorkload -OtherServers $OtherServers

    # Create the job
    $timestamp = Get-Date -Format "yyyyMMdd.HHmmss"
    # Generate a unique replica name
    Write-Host "Usable tags for replica name:
    {YYYY} = 4 digit year
    {MM} = 2 digit month
    {DD} = 2 digit day
    {HH} = 2 digit hour
    {SS} = 2 digit second
    {MS} = milliseconds
    {IP} = IP of the new VM
    If no name is entered, a default name will be generated in the following format d42-carbonite-[source ip].[YYYYMMDD]"
    $UserReplicaName = Read-Host -Prompt 'Please enter the replica name to be created on the ESX server'
    if (!$UserReplicaName) {
        $DtJobOptions.JobOptions.VRAOptions.ReplicaVmInfo.DisplayName = "d42-carbonite-$DtSourceName.$timestamp"
    }  
    else {
        $UserReplicaName = $UserReplicaName.
        Replace("{YYYY}" , (Get-Date -Format "yyyy")).
        Replace("{HH}", (Get-Date -Format "HH")).
        Replace("{MM}", (Get-Date -Format "MM")).
        Replace("{DD}", (Get-Date -Format "dd")).
        Replace("{MS}", (Get-Date -Format "ms")).
        Replace("{SS}", (Get-Date -Format "ss")).
        Replace("{IP}", $DtSourceName)
    }
    
    # Saving the above id to a file for other scripts to use
    $DtJobOptions.JobOptions.VRAOptions.ReplicaVmInfo.DisplayName | Out-File -FilePath .\vmName.txt
    # Add "vmware" subtype flag for ESX type migrations for D42
    "vmware" | Out-File -FilePath .\vmName.txt -Append
    # Make the failover start right after mirroring completes (0 - auto start, 1 - manual start)
    $DtJobOptions.JobOptions.CoreMonitorOptions.MonitorConfiguration.ProcessingOptions = 0
    $DtJobGuidForVraMove = New-DtJob -ServiceHost $DtTarget -Source $DtSource -OtherServers $OtherServers -JobType $DtJobType -JobOptions $DtJobOptions.JobOptions
 
    # Start the job
    Start-DtJob -ServiceHost $DtTarget -JobId $DtJobGuidForVraMove
}
Catch { 
    $ErrorMessage = "ERROR: " + $_.Exception.Message    
    $FailedItem = $_.Exception.ItemName
    Write-Error -Exception $_.Exception -Message "An error has occurred: 
    $_.Exception.ItemName"
    Add-Content -Path $reportPath -Value $ErrorMessage
}
Finally {
    # Close the connections for the server objects.
    Disconnect-DtServer -ServiceHost $DtSource
    Disconnect-DtServer -ServiceHost $DtTarget
    Disconnect-DtServer -ServiceHost $VimTarget
}