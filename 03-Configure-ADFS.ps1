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

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`

        [Security.Principal.WindowsBuiltInRole] "Administrator"))
{

    Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    Break

}

if (-not ([System.Environment]::OSVersion.Version.Major -eq 6 -and [System.Environment]::OSVersion.Version.Minor -eq 3))
{

    Write-Warning "AD FS 3.0 can only be installed on Windows Server 2012 R2."
    Break

}

$logFile = $pwd.Path + "\Logs\03-Configure-ADFS-" + (Get-Date).ToString('MM-dd-yyyy-HH-mm') + ".txt" 
Start-Transcript -Path $logFile

$currentExecutionPolicy = Get-ExecutionPolicy

if(-not ($currentExecutionPolicy -eq "Unrestricted")){
    Write-Warning "Temporarily setting execution policy unrestricted"
    Set-ExecutionPolicy Unrestricted -Force
}

#endregion PREREQUISITES

Import-Module ADFS
Add-ADFSRelyingPartyTrust -Name "Amazon Web Services" -MetadataURL "https://signin.aws.amazon.com/static/saml-metadata.xml" -MonitoringEnabled:$true -AutoUpdateEnabled:$true

$ruleSet = New-AdfsClaimRuleSet -ClaimRuleFile ((pwd).Path + "\claims.txt")
$authSet = New-AdfsClaimRuleSet -ClaimRuleFile ((pwd).Path + "\auth.txt")
Set-AdfsRelyingPartyTrust -TargetName "Amazon Web Services" -IssuanceTransformRules $ruleSet.ClaimRulesString -IssuanceAuthorizationRules $authSet.ClaimRulesString 

$signInPage = "https://" + [System.Net.Dns]::GetHostByName(($env:computerName)).Hostname + "/adfs/ls/idpinitiatedsignon.aspx"
Start-Process $signInPage

#region FINALIZING

if(-not ($currentExecutionPolicy -eq "Unrestricted")){

    Write-Host "`n"
    Write-Host "Restoring original execution policy" -ForegroundColor Green
    Set-ExecutionPolicy $currentExecutionPolicy -Force

}

Stop-Transcript

#endregion FINALIZING