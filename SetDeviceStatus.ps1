Function Set-D42DeviceStatus {
    # Params
    Param(
        [string]$baseURL,
        [ValidateSet('Put', 'Post')]
        [string]$method,
        [string]$username,
        [securestring]$password,
        [string]$devName,
        [ValidateSet('yes', 'no')]
        [string]$inService
    )
    
    # Authentication
    $apiDeviceURL = $baseURL + "api/1.0/device/"
    $apiDevice = $baseURL + "api/1.0/devices/name/$devName"
    $reportPath = "C:\migrations\log.txt"
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $password
    $passPlain = $Credential.GetNetworkCredential().Password

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

        [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls11    
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
            name       = $devName  # device name
            in_service = $inService # yes or no to enable/disable the device
        }
        $result = Invoke-RestMethod -Uri $apiDeviceURL -Body $body -Headers $headers -Method Post 
        
        # Get the old device info
        $result = Invoke-RestMethod -Uri $apiDevice -Headers $headers -Method Get 
        
        # Create the migrated device in D42
        $vmName = (Get-Content -Path .\vmName.txt)[0]
        if ($result.tags.PsObject.BaseObject.ToString() -eq 'System.Object[]') {
            $tags = ''
        }     
        $body = @{
            name            = $vmName
            type            = 'virtual'
            virtual_subtype = (Get-Content -Path .\vmName.txt)[1]         
            in_service      = "yes" 
            service_level   = $result.service_level
            tags            = $tags
            notes           = $result.notes
        }
        $result = Invoke-RestMethod -Uri $apiDeviceURL -Body $body -Headers $headers -Method Post
        Write-Host [ $result.msg[2] $result.msg[0] ]
    }
}