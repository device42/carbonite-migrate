carbonite-migrate
=================

# Migrate devices using Carbonite Migrate.
 
User requirements
=================

**The following software must be running/installed**:

1. Device42 16.10.00+

2. Carbonite Replication Console 8.3.0.293+

3. Carbonite Migrate — the machine you will be migrating (source) **must** have Carbonite Migrate software installed and licensed on it. This machine also needs to be added to the Carbonite Replication Console on your Carbonite server:
![alt](https://s3.amazonaws.com/device42/carbonite-migrate/mstsc_Fv0eg6nSnA.png)

4. Carbonite Target software must be installed on the replication server and the server added to the Carbonite console application. This machine will be called the "Carbonite target" in the script's questions.
![alt](https://s3.amazonaws.com/device42/carbonite-migrate/mstsc_eqCIP7SL5Z.png)

5. PowerShell 5.1 on the machine running the scripts: if you are using Windows 10, you already have the necessary
    version of PowerShell, if you are using Windows 7/8/8.1; please download the
    Windows Management Framework 5.1 that includes the necessary updates to
    Windows PowerShell -\> [Download WMF
    5.1](https://www.microsoft.com/en-us/download/details.aspx?id=54616)

6. For convenience, you can use PowerShell ISE, which includes a dual screen
    layout where you can view the script and run it at the same time using a
    GUI. Run it by pressing the Windows key and typing “powershell ise”.
    ![PS ISE](https://s3.amazonaws.com/device42/carbonite-migrate/uFcC013.png)

7.  If you never ran a PowerShell script before, you will need to perform the
    following steps:

    -   **Start Windows PowerShell with the "Run as administrator" option.** Only
        members of the Administrators group on the computer can change the
        execution policy.

    -   Enable running unsigned scripts by entering: `Set-ExecutionPolicy
        RemoteSigned`

    ![alt](https://s3.amazonaws.com/device42/carbonite-migrate/WqSTevh.png)

Creating a CSV export for Carbonite Migration
=============================================

1.  Access the D42 website and select Apps \> Business Application from the main
    toolbar.

![alt](https://s3.amazonaws.com/device42/carbonite-migrate/3lv9tKf.jpg)

2.  On the next screen, add a desired business application(s) or select an existing
    one(s) from the list, select the “Create Migration for” item from the “Action”
    dropdown and hit the lightning button to the right.

![alt](https://s3.amazonaws.com/device42/carbonite-migrate/Fr4uHmV.jpg)

3.  Select the “Carbonite CSV” target for migration from the dropdown list and
    click the “Export” button.

![alt](https://s3.amazonaws.com/device42/carbonite-migrate/mCa2TeG.jpg)

4.  You will be prompted to save a CSV export file with server information for
    the migration. Save it to some directory. This file is used to enter server
    data into the PowerShell script and Carbonite job creation. 

# Using a PowerShell Carbonite migration script

1.  Install the Carbonite client on your machine.

2.  Download the D42 Carbonite PowerShell scripts from the D42 GitHub page at:
    [Carbonite migration scripts](https://github.com/device42/carbonite-migrate)

3.  **Start Windows PowerShell with the "Run as administrator" option**. You can do this by clicking the Start button, typing "powershell", right-click on the PS icon and select "Run as administrator". You will see a Windows PowerShell window with "Administrator: Windows PowerShell" in the titlebar.
![alt](https://s3.amazonaws.com/device42/carbonite-migrate/Code_ODM7dyRKI1.png)
![alt](https://s3.amazonaws.com/device42/carbonite-migrate/powershell_25ClvB9tSu.png)

4.  Run the script by entering its name in PowerShell:    
    `For ESX: ./ESX-EVRAMigrationJobScript.ps1`

    `For Hyper-V: ./Hyper-VMigrationJobScript.ps1`

5.  Answer questions when prompted:
    1. Enter the location of the CSV file generated on D42 website. The source machine IP will be parsed from this file.
    2. The "Carbonite target IP" is the replication server and the server added to the Carbonite console application. This machine stores the protected data.
    3. The "ESX host IP/HyperV host IP" is the ESXi/HyperV VM Server which will host the replica of your source machine.
    4. When asked for the type of job you will be creating, please be aware that the available choices differ for Windows and Linux OSs. The following jobs are available: 

        **Migrate for Windows jobs:**
        - **VraMove** — Full server to ESX migration or full server to Hyper-V migration

        **Migrate for Linux jobs:**        
        - **MoveLvra** — Full server to ESX migration


    ![alt](https://s3.amazonaws.com/device42/carbonite-migrate/mstsc_fEiKKgtir1.png)

6.  You will then be asked to create a replica name, which will be the name of
    the migrated machine on the VMware server and the name appearing in D42. You
    can use the following tags:

    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    {YYYY} = 4 digit year  
    {MM} = 2 digit month  
    {DD} = 2 digit day  
    {HH} = 2 digit hour
    {MN} = 2 digit minutes
    {SS} = 2 digit seconds
    {MS} = milliseconds
    {IP} = Current IP of the VM to be migrated
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    Using these tags you can create unique names, for example entering:
    `"d42-carbonite-[source ip].[YYYYMMDD.HHMNSS]"` will create a name
    equivalent to: `"d42-carbonite-[current vm ip].20200412.092311"`.

7.  You should answer 'Yes' to the question about the vmName.txt file if asked.

8.  The script will execute and issue a job id \# upon completion:

    ![alt](https://s3.amazonaws.com/device42/carbonite-migrate/5JVARpn.png)

9.  While the script is running or when it has finished, you will check the job
    status and modify the D42 device, which was migrated by running the job
    monitoring script `"JobMonitorScript.ps1"`.

Using the job monitoring script
===============================

1.  Run the script by entering its name in PowerShell:
    `./JobMonitorScript.ps1`

2.  Answer the questions when prompted as you have in the migration script above.

3.  The script will report the job status of the migration in 30-second intervals.

4.  Once the job completes and the job fails over (successfully completes), the
    script will mark the old device as not in service.

    ![](https://s3.amazonaws.com/device42/carbonite-migrate/4LLMFCE.png)

5.  A new device which has been migrated over to, will be added automatically 
    with the name you’ve given your replica in the migration script step:

    ![](https://s3.amazonaws.com/device42/carbonite-migrate/kzsKrDo.png)
