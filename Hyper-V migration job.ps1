# Server to Hyper-V migration job
Try {

    # Read the Migrations.csv file 
    $migrationPath = Read-Host -Prompt 'Please enter the location of the Migrations.csv file (Enter for default "C:\migrations\Migrations.csv")'
    if (!$migrationPath) {
        # Set the path for the downloaded migrations file here...
        $migrationPath = 'C:\migrations\Migrations.csv'
    }
    $newstreamreader = New-Object System.IO.StreamReader("$migrationPath")
    $newstreamreader.ReadLine()     # skip the header
    $credentials = $newstreamreader.ReadLine().Split(",")

    # Set credentials
    $username = $credentials[0]
    $source_ip = $credentials[1]
    $source_user = $credentials[2]
    $source_pw = ConvertTo-SecureString -String $credentials[3] -AsPlainText -Force 
    $newstreamreader.Dispose()

    $DtSourceName = $source_ip
    $DtSourceUserName = $source_user
    $DtSourcePassword = $source_pw

    $reportPath =  "C:\migrations\error.log"

    # Target server and credentials (Hyper-V host)
    $DtTargetName = Read-Host -Prompt 'Please enter the target IP for the migration'
    if (!$DtTargetName) {
        $DtTargetName = '10.90.12.2'
    }
    $DtTargetUserName = Read-Host -Prompt 'Please enter the target user name'
    if (!$DtTargetUserName) {
        $DtTargetUserName = "Administrator"
    }

    $DtTargetPassword = Read-Host -AsSecureString -Prompt "Please enter the target user password"

    if (!$DtTargetUserName) {
        $DtTargetUserName = "Administrator"
    }  

    # Type of workload you will be protecting and type of job you will be creating
    $DtWorkloadType = Read-Host -Prompt 'Please enter the type of job you will be creating [default = VraMove]'
    if (!$DtWorkloadType) {
        $DtWorkloadType = "VraMove"
    }
    $DtJobType = $DtWorkloadType
    
    $TargetCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $DtTargetUserName, $DtTargetPassword
    $SourceCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $credentials[2], $DtSourcePassword

    # Import the Carbonite PowerShell module
    # This may be \Service\ or \Console\ depending on your installation
    Import-Module "C:\Program Files\Carbonite\Replication\Console\DoubleTake.PowerShell.dll"
 
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
    # Create source and target objects
    $DtSource = New-DtServer -Name $DtSourceName -UserName $DtSourceUserName -Password $SourceCredential.GetNetworkCredential().Password
    $DtTarget = New-DtServer -Name $DtTargetName -UserName $DtTargetUserName -Password $TargetCredential.GetNetworkCredential().Password


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
    $timestamp = Get-Date -Format "ddMMyyyy.HHmmss"
    # Generate a unique replica name
    $DtJobOptions.JobOptions.VRAOptions.ReplicaVmInfo.DisplayName = "Replica-$($source_ip).$timestamp"
    # Make the failover start right after mirroring completes (0 - auto start, 1 - manual start)
    # $DtJobOptions.JobOptions.CoreMonitorOptions.MonitorConfiguration.ProcessingOptions = 0

    # Create the job
    $DtJobGuidForVraMove = New-DtJob -ServiceHost $DtTarget -Source $DtSource -OtherServers $OtherServers -JobType $DtJobType -JobOptions $DtJobOptions.JobOptions 

    # Start the job
    Start-DtJob -ServiceHost $DtTarget -JobId $DtJobGuidForVraMove
}
Catch {
    $ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.ItemName
    Write-Error -Exception $_.Exception -Message "An error has occurred: 
    $_.Exception.ItemName"
    Add-Content -Path $reportPath -Value $ErrorMessage
}
Finally {
    # Close the connections for the server objects.
    Disconnect-DtServer -ServiceHost $DtSource
    Disconnect-DtServer -ServiceHost $DtTarget
}