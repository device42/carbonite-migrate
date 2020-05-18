Function Set-D42DeviceStatus {
    # Params
    Param(
        [string]$baseURL,
        [ValidateSet('Put', 'Post')]
        [string]$method,
        [string]$username,
        [securestring]$password,
        [array]$devInfo,
        [ValidateSet('yes', 'no')]
        [string]$inService,
        [string]$reportPath
    )
    
    # Authentication
    $apiDeviceURL = $baseURL + "/api/1.0/device/"
    $apiDevice = $baseURL + "/api/1.0/devices/name/" + $devInfo[0]    
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $password
    $passPlain = $Credential.GetNetworkCredential().Password
    $vmPath = ($PSScriptRoot + "\vmName.txt")

    $encodedCredentials = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$username`:$passPlain"))
    
    # POST
    $headers = @{
        'Authorization' = "Basic $encodedCredentials"
        'Content-Type'  = 'application/x-www-form-urlencoded'
    }        

    # $result = Invoke-RestMethod -Uri $apiDeviceURL -Body $body -Headers $headers -Method Post -SslProtocol Tls -SkipCertificateCheck 
    Try {    
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
    }
    Catch {
        $ErrorMessage = "ERROR: " + $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Error -Exception $_.Exception -Message "An error has occurred: 
        $_.Exception.ItemName"
        Add-Content -Path $reportPath -Value $ErrorMessage
    }
    Finally {        
        # Disable the migrated device
        $body = @{
            name       = $devInfo[0]  # device name
            in_service = $inService # yes or no to enable/disable the device
        }
        $result = Invoke-RestMethod -Uri $apiDeviceURL -Body $body -Headers $headers -Method $method 
        
        # Get the old device info
        $result = Invoke-RestMethod -Uri $apiDevice -Headers $headers -Method Get
        
        # Create the migrated device in D42
        $vmName = $devInfo[1]
        $virtSubtype = $devInfo[3]
        if ($result.tags.PsObject.BaseObject.ToString() -eq 'System.Object[]') {
            $tags = ''
        }     
        $body = @{
            name            = $vmName
            type            = 'virtual'
            virtual_subtype = $virtSubtype         
            in_service      = "yes" 
            service_level   = $result.service_level
            tags            = $tags
            notes           = $result.notes
            customer        = $result.customer
            object_category = $result.object_category
        }
        $result = Invoke-RestMethod -Uri $apiDeviceURL -Body $body -Headers $headers -Method $method
        Add-Content -Path $reportPath -Value "[$($result.msg[2]) $($result.msg[0])]"
        Write-Host [ $result.msg[2] $result.msg[0] ]
    }
}
