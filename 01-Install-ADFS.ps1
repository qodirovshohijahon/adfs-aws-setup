#########################################################################
# Copyright 2015 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You may not use this file except in compliance with the License. A copy of the License is located at
#
# http://aws.amazon.com/apache2.0/
#
# or in the "license" file accompanying this file. This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
#########################################################################

#region PREREQUISITES

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(

        [Security.Principal.WindowsBuiltInRole] "Administrator"))
{

    Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    break

}

if (-not ([System.Environment]::OSVersion.Version.Major -eq 6 -and [System.Environment]::OSVersion.Version.Minor -eq 3))
{

    Write-Warning "AD FS 3.0 can only be installed on Windows Server 2012 R2."
    break

}

$currentExecutionPolicy = Get-ExecutionPolicy

if($currentExecutionPolicy -eq "Restricted"){

    Write-Warning "This script requires at least RemoteSigned Execution Policy. Please run Set-ExecutionPolicy RemoteSigned."
    break

}

$logFile = $pwd.Path + "\Logs\01-Install-ADFS-" + (Get-Date).ToString('MM-dd-yyyy-HH-mm') + ".txt" 
Start-Transcript -Path $logFile

if(-not ($currentExecutionPolicy -eq "Unrestricted")){
    Write-Warning "Temporarily setting execution policy unrestricted"
    Set-ExecutionPolicy Unrestricted -Force
}

. ((pwd).Path + "\Utilities\New-SelfSignedCertificateEx\New-SelfSignedCertificateEx.ps1")

#endregion PREREQUISITES

#region AD FS INSTALLATION

Write-Host "Installing AD FS 3.0 Role" -ForegroundColor Green
Import-Module Servermanager
Add-WindowsFeature ADFS-Federation

#endregion AD FS INSTALLATION

#region SELF-SIGNED CERTIFICATE CREATION

Write-Host "`n"
Write-Host ("Creating a self-signed certificate for " + [System.Net.Dns]::GetHostByName(($env:computerName)).Hostname) -ForegroundColor Green
New-SelfsignedCertificateEx -Subject ("CN=" + [System.Net.Dns]::GetHostByName(($env:computerName)).Hostname) -EKU "Server Authentication", "Client authentication" -KeyUsage "KeyEncipherment, DigitalSignature" -StoreLocation "LocalMachine"
# Get the thumbprint from the last created certificate of the name we just created
$cert = (dir cert:\localmachine\My -recurse | where {$_.Subject -match $test} | Select-Object -Last 1).thumbprint
Write-Host ("-----------------------------------------------------------------------------------------") -ForegroundColor Green
Write-Host ("Self-signed certificate thumbprint: " + $cert) -ForegroundColor Green
Write-Host ("-----------------------------------------------------------------------------------------") -ForegroundColor Green

#endregion SELF-SIGNED CERTIFICATE CREATION

#region AD FS DEPLOYMENT

Import-Module ADFS

# Get the credential used for the federation service account
$serviceAccountCredential = Get-Credential -Message "Enter the credential for the Federation Service Account. Please include the NETBIOS, i.e. EXAMPLE\adfssvc."

Write-Host "`n"
Write-Host "Configuring AD FS 3.0 Farm" -ForegroundColor Green

try{

    $result = Install-AdfsFarm `
                    -CertificateThumbprint:$cert `
                    -FederationServiceDisplayName $env:computerName `
                    -FederationServiceName ([System.Net.Dns]::GetHostByName(($env:computerName)).Hostname) `
                    -ServiceAccountCredential $serviceAccountCredential `                    -OverwriteConfiguration

    if(!($result.Status -eq "Error")){

        $metadataUrl = "https://localhost/federationmetadata/2007-06/federationmetadata.xml"

        [Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        $webClient = new-object System.Net.WebClient
        $webClient.DownloadFile( $metadataUrl, ((pwd).Path + "\federationmetadata.xml") )
        Write-Host ("AD FS 3.0 Federation metadata saved to: " + (pwd).Path + "\federationmetadata.xml")

    }else{

        Write-Error $result.Message

        Write-Host "`n"
        Write-Warning "Removing the created self-signed certificate"
        $certPath = "cert:\LocalMachine\my\" + $cert
        Remove-Item -Path $certPath

    }

}catch{

    Write-Error $_.Exception.Message

    Write-Host "`n"
    Write-Warning "Removing the created self-signed certificate"
    $certPath = "cert:\LocalMachine\my\" + $cert
    Remove-Item -Path $certPath

}

#endregion AD FS Deployment

#region FINALIZING

if(-not ($currentExecutionPolicy -eq "Unrestricted")){

    Write-Host "`n"
    Write-Host "Restoring original execution policy" -ForegroundColor Green
    Set-ExecutionPolicy $currentExecutionPolicy -Force

}

Stop-Transcript

#endregion FINALIZING