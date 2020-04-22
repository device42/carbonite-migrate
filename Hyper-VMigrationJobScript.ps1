# Server to Hyper-V migration job
Try {
    # Import the Carbonite PowerShell module
    # This may be \Service\ or \Console\ depending on your installation
    Import-Module "$PSScriptRoot\DoubleTake.PowerShell.dll"
    # Source server and credentials
    # Read the Migrations.csv file 
    $migrationPath = Read-Host -Prompt 'Please enter the location of the migration CSV file (Without quotes like C:\migrations\carbonite-migration.csv)'
    if (!$migrationPath) {
        # Set the path for the downloaded migrations file here...
        $migrationPath = "$PSScriptRoot\carbonite-migration.csv"
    }
    $migrationData = Get-Content -Path $migrationPath
    $reportPath = $PSScriptRoot + "\errors.log"
    $devInfoPath = $PSScriptRoot + "\vmName.txt"

    # Process each device from the migrations csv file
    Foreach ($dev in $migrationData) {        
        $credentials = $dev.Split(",")

        # Set credentials
        $DtDeviceName = $credentials[0]
        $DtSourceName = $credentials[1]
        $DtSourceUserName = $credentials[2]
        $DtSourcePassword = ConvertTo-SecureString -String $credentials[3] -AsPlainText -Force 

        if ($DtDeviceName -eq "device_name") {
            continue
        }
        if (Test-Path $devInfoPath -PathType Leaf) {
            Write-Host "A previous device info file was found, it should be removed..."
            Remove-Item -Path $devInfoPath -Confirm
        }

        # Target server and credentials
        Add-Content -Path "$PSScriptRoot\$DtDeviceName.log" -Value "[PROCESSING $($DtDeviceName.ToUpper())]"
        Write-Host "[PROCESSING $($DtDeviceName.ToUpper())]"
        $DtTargetName = Read-Host -Prompt 'Please enter the Carbonite target IP for the migration'
        if (!$DtTargetName) {
            $DtTargetName = '10.90.11.22'
        }
        $DtTargetUserName = Read-Host -Prompt 'Please enter the Carbonite target user name'
        if (!$DtTargetUserName) {
            $DtTargetUserName = "Administrator"
        }    

        $DtTargetPassword = Read-Host -AsSecureString -Prompt "Please enter the Carbonite target user password"

        $TargetCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $DtTargetUserName, $DtTargetPassword
        $SourceCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $DtSourceUserName, $DtSourcePassword

        # Hyper-V host and credentials
        # If you are using vCenter, specify your vCenter.
        # Only specify an Hyper-V host if you are using Hyper-V standalone.
        $DtHostName = Read-Host -Prompt 'Please enter the Hyper-V host IP for the migration'
        if (!$DtHostName) {
            $DtHostName = "10.90.0.12"    
        }
        $DtHostUserName = Read-Host -Prompt 'Please enter the Hyper-V host user name'
        if (!$DtHostUserName) {
            $DtHostUserName = "root"
        }

        $DtHostPassword = Read-Host -AsSecureString -Prompt "Please enter the Hyper-V host user password"

        $HostCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $DtHostUserName, $DtHostPassword

        # Type of workload you will be protecting and type of job you will be creating
        $DtWorkloadType = Read-Host -Prompt 'Please enter the type of job you will be creating [default = VraMove]'
        if (!$DtWorkloadType) {
            $DtWorkloadType = "VraMove"
        }
        $DtJobType = $DtWorkloadType

        # Create source and target objects
        $DtSource = New-DtServer -Name $DtSourceName -UserName $DtSourceUserName -Password $SourceCredential.GetNetworkCredential().Password
        $DtTarget = New-DtServer -Name $DtTargetName -UserName $DtTargetUserName -Password $TargetCredential.GetNetworkCredential().Password

        # Create Hyper-V host appliance object
        # If you are using vCenter, specify your vCenter.
        # Only specify an Hyper-V host if you are using Hyper-V standalone.        
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
        {MN} = 2 digit minutes
        {SS} = 2 digit second
        {MS} = milliseconds
        {IP} = Current IP of the VM to be migrated
        If no name is entered, a default name will be generated in the following format d42-carbonite-[source ip].[YYYYMMDD.HHMMSS]"
        $UserReplicaName = Read-Host -Prompt 'Please enter the replica name to be created on the Hyper-V server'
        if (!$UserReplicaName) {
            $DtJobOptions.JobOptions.VRAOptions.ReplicaVmInfo.DisplayName = "d42-carbonite-$DtSourceName.$timestamp"
        }  
        else {
            $UserReplicaName = $UserReplicaName.
            Replace("{YYYY}" , (Get-Date -Format "yyyy")).
            Replace("{HH}", (Get-Date -Format "HH")).
            Replace("{MM}", (Get-Date -Format "MM")).
            Replace("{DD}", (Get-Date -Format "dd")).
            Replace("{MN}", (Get-Date -Format "mm")).
            Replace("{MS}", (Get-Date -Format "ms")).
            Replace("{SS}", (Get-Date -Format "ss")).
            Replace("{IP}", $DtSourceName)
        }    
   
        # Make the failover start right after mirroring completes (0 - auto start, 1 - manual start)
        $DtJobOptions.JobOptions.CoreMonitorOptions.MonitorConfiguration.ProcessingOptions = 0        
        # Change the initial HyperV startup memory in case of memory errors from Carbonite Console (in bytes)
        $DtJobOptions.JobOptions.VRAOptions.ReplicaVMInfo.Memory = 4096000000
        $DtJobOptions.JobOptions.VRAOptions.WorkloadCustomizationOptions.ShouldShutdownSource = 0        

        $DtJobGuidForVraMove = New-DtJob -ServiceHost $DtTarget -Source $DtSource -OtherServers $OtherServers -JobType $DtJobType -JobOptions $DtJobOptions.JobOptions

        # Save the above id to a file for other scripts to use
        # Add "hyperv" subtype flag for Hyper-V type migrations for D42
        "$DtDeviceName,$($DtJobOptions.JobOptions.VRAOptions.ReplicaVmInfo.DisplayName),$DtJobGuidForVraMove,hyperv" | 
        Out-File -FilePath ($PSScriptRoot + "\vmName.txt") -Append

        # Start the job
        Start-DtJob -ServiceHost $DtTarget -JobId $DtJobGuidForVraMove
    }
}
Catch {
    $ErrorMessage = "[$(Get-Date)] ERROR: " + $_.Exception.Message 
    $FailedItem = $_.Exception.ItemName
    Write-Error -Exception $_.Exception -Message "An error has occurred: 
    $_.Exception.ItemName"
    Add-Content -Path $reportPath -Value $ErrorMessage
}
Finally {
    # Close the connections for the server objects.
    if ($DtSource) {
        Disconnect-DtServer -ServiceHost $DtSource
    }
    if ($DtTarget) {
        Disconnect-DtServer -ServiceHost $DtTarget
    }
    if ($VimTarget) {
        Disconnect-DtServer -ServiceHost $VimTarget
    }    
}