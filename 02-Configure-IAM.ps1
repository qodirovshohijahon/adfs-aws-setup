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

if (!(Get-Module -ListAvailable -Name AWSPowerShell)) {

    Write-Warning "AWSPowerShell is not installed. Please download it from https://aws.amazon.com/powershell/"
    break

}

Import-Module AWSPowershell

if(!(Test-Path ((pwd).Path+"\federationmetadata.xml"))){

        $metadataUrl = "https://localhost/federationmetadata/2007-06/federationmetadata.xml"

        [Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        $webClient = new-object System.Net.WebClient
        $webClient.DownloadFile( $metadataUrl, ((pwd).Path+"\federationmetadata.xml"))
        Write-Host "AD FS 3.0 Federation metadata saved to: "((pwd).Path+"\federationmetadata.xml") -ForegroundColor Green

}

$logFile = $pwd.Path + "\Logs\02-Configure-IAM-" + (Get-Date).ToString('MM-dd-yyyy-HH-mm') + ".txt" 
Start-Transcript -Path $logFile

#endregion PREREQUISITES

Write-Host "How many AWS accounts do you want to configure? " -NoNewline -ForegroundColor Yellow
$accounts = [int] (Read-Host)

Write-Host "You will now be asked for the IAM access key and secret access key of an IAM user in each of the" $accounts "AWS accounts you want to configure" -ForegroundColor Green
Write-Warning "NOTE: A SAML provider and two IAM roles with no permissions will be created in each account. Those IAM roles will trust the created SAML Provider."

while($accounts -gt 0){

    #region IAM CONFIGURATION

    $accounts--

    try{

        # Get the credentials to complete the IAM configuration
        $iamUser = Get-Credential -Message "Enter the IAM access key and secret access key for the IAM configuration"

        $samlProvider = New-IAMSAMLProvider -Name "ADFS" -SAMLMetadataDocument (Get-Content .\federationmetadata.xml) -AccessKey $iamUser.UserName -SecretKey $iamUser.GetNetworkCredential().Password

        Write-Host "SAML Provider "$samlProvider" created!" -ForegroundColor Green

        $ADFStrustPolicy = @'
        {
          "Version": "2012-10-17",
          "Statement": [
            {
              "Sid": "",
              "Effect": "Allow",
              "Principal": {
                "Federated": "$SAMLPROVIDERARN"
              },
              "Action": "sts:AssumeRoleWithSAML",
              "Condition": {
                "StringEquals": {
                  "SAML:aud": "https://signin.aws.amazon.com/saml"
                }
              }
            }
          ]
        }
'@

        $ADFStrustPolicy = $ADFStrustPolicy.Replace('$SAMLPROVIDERARN', $samlProvider).Trim()

        Write-Host "Creating IAM Role 'ADFS-Production'" -ForegroundColor Green
        $output = New-IAMRole -AssumeRolePolicyDocument $ADFStrustPolicy -RoleName "ADFS-Production" -AccessKey $iamUser.UserName -SecretKey $iamUser.GetNetworkCredential().Password
        $output | fl RoleName,RoleId,CreateDate,Arn

        Write-Host "Creating IAM Role 'ADFS-Dev'" -ForegroundColor Green
        $output = New-IAMRole -AssumeRolePolicyDocument $ADFStrustPolicy -RoleName "ADFS-Dev" -AccessKey $iamUser.UserName -SecretKey $iamUser.GetNetworkCredential().Password
        $output | fl RoleName,RoleId,CreateDate,Arn

    }catch{

        Write-Error $_.Exception.Message

    }

    #endregion IAM CONFIGURATION

}

#region FINALIZING

Stop-Transcript

#endregion FINALIZING