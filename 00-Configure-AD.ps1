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
    Break

}

if (!(Get-Module -ListAvailable -Name ActiveDirectory)) {

    Write-Host "Installing AD Powershell Module" -ForegroundColor Green
    Import-Module Servermanager
    Add-WindowsFeature RSAT-AD-PowerShell

}

$logFile = $pwd.Path + "\Logs\00-Configure-AD-" + (Get-Date).ToString('MM-dd-yyyy-HH-mm') + ".txt" 
Start-Transcript -Path $logFile

#endregion PREREQUISITES

#region PARAMETERS
$myProdGroup = "AWS-Production"
$myDevGroup = "AWS-Dev"
$groups = @($myProdGroup, $myDevGroup)
$adfsServiceAccountName = "ADFSSVC"
#endregion PARAMETERS

#region FUNCTIONS
Function Configure-User{
        param(
        [string]$user,
        [string]$prodGroup = $myProdGroup,
        [string]$devGroup = $myDevGroup
        )

        Write-Host "#### Configuration of user "$user" ####"
        $currentUser = Get-ADUser -Identity $user -Properties url,memberof
        $currentAccounts = $currentUser.url

        $choice = 1

        if($currentAccounts){

            Write-Host "User" $user "has already access to the following AWS accounts:" $currentAccounts -ForegroundColor Yellow

            $title = "AWS account association"
            $message = "Do you want to keep the existing AWS account associations? (" + $currentAccounts + ")"

            $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
                "Keep the existing associations."

            $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
                "You will be asked to specify new AWS account IDs"

            $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

            $choice = $host.ui.PromptForChoice($title, $message, $options, 0) 

        }

        switch ($choice){
                1 {
            
                    Write-Host "List the AWS account IDs you want this user to access (i.e. 123456789012,111122223333) : " -NoNewline -ForegroundColor Yellow
                    $accounts = (Read-Host).Split(",")

                    if($accounts){
    
                        foreach($account in $accounts){

                            if(!($account -match '^[0-9]{12}$')){

                                Write-Error $account " is not a valid 12 digit AWS account ID."
                                break
                            }

                        }

                        Set-ADUser -Identity $user -Replace @{url=$accounts;}
                        Write-Host "Accounts "$accounts" successfully associated to" $user "!" -ForegroundColor Green

                    }

                }
        }

        $currentAccess = $currentUser.memberof | ? {$_ -like "CN=AWS*"} | % { $_.Split(",").Split("=")[1] }

        if($currentAccess){

            Write-Host "User" $user "has the following level of access:" $currentAccess -NoNewline -ForegroundColor Yellow

            foreach($group in $currentAccess){

                #AD group membership
                $title = "AD group membership for AWS access"
                $message = "Do you want to keep " + $group + "?"

                $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
                    ("Add the specified user to " + $group + ".")

                $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
                    "Nothing happens."

                $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

                $access = $host.ui.PromptForChoice($title, $message, $options, 0) 

                switch ($access){
                    1 {
            
                        Remove-ADGroupMember -Identity $group -Members $user -Confirm:$false
                        Write-Host "User" $user "successfully removed from " $group "!" -ForegroundColor Green
                    }

                }
                

            }
           
        }
        
        #AD group membership
        $title = "AD group membership for AWS access"
        $message = "What level of access do you want to grant?"

        $prod = New-Object System.Management.Automation.Host.ChoiceDescription "&Production", `
            ("Add the specified user to" + $prodGroup + ".")

        $dev = New-Object System.Management.Automation.Host.ChoiceDescription "&Dev", `
            ("Add the specified user to" + $devGroup + ".")

        $options = [System.Management.Automation.Host.ChoiceDescription[]]($prod, $dev)

        $access = $host.ui.PromptForChoice($title, $message, $options, 0) 

        switch ($access){
            0 {
            
                Add-ADGroupMember -Identity $prodGroup -Members $user
                Write-Host "User" $user "successfully added to " $prodGroup "!" -ForegroundColor Green
            }

            1{

                Add-ADGroupMember -Identity $devGroup -Members $user
                Write-Host "User" $user "successfully added to " $devGroup "!" -ForegroundColor Green

            }
        }

}

#endregion FUNCTIONS

try{

    Import-Module ActiveDirectory

    #Create two AD groups if they don't exist already
    $title = "Active Directory AWS groups creation"
    $message = "Do you want to create two AD groups called " + $myProdGroup + " and " + $myDevGroup + "?"

    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
        ("Create two AD groups called " + $myProdGroup + "and" + $myDevGroup + ".")

    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
        "Nothing happens."

    $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

    $result = $host.ui.PromptForChoice($title, $message, $options, 0) 

    switch ($result){
        0 {
            
            foreach($group in $groups){

                $filter = "CN=" + $group + ",CN=Users,DC=" + $env:userdnsdomain.ToLower().Split(".")[0] + ",DC=" + $env:userdnsdomain.ToLower().Split(".")[1]

                if(![bool](Get-ADObject -Filter {DistinguishedName -eq $filter })){

                    New-ADGroup $group -GroupScope Global -GroupCategory Security
                    Write-Host "AD Groups" $group "successfully created!" -ForegroundColor Green

                }else{

                    Write-Host "AD Groups" $group "already exists, skipping..." -ForegroundColor Yellow

                }

            }
            
        }
    }

    #Create AD FS service account if needed
    $title = "AD FS service account creation"
    $message = "Do you want to create AD FS service account? Username and password will be requested."

    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
        "Create a new Active Directory user with the specified username and password."

    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
        "Nothing happens."

    $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

    $result = $host.ui.PromptForChoice($title, $message, $options, 0) 

    switch ($result){
        0 {
            
            $user = Get-Credential -Message "Enter the username and password of the AD FS service account you want to create" -UserName $adfsServiceAccountName

            if(![bool](Get-ADObject -Filter {sAMAccountname -eq $user.UserName})){

                New-ADUser -Name $user.UserName -AccountPassword $user.Password -EmailAddress ($user.UserName + "@" + $env:userdnsdomain.ToLower()) -Enabled $true
                Write-Host "User"$user.Username"successfully created!" -ForegroundColor Green

            }else{

                Write-Host "AD user" $user.UserName "already exists!" -ForegroundColor Yellow

            }
            
        }
    }
  
    Write-Host "How many new Active Directory users do you want to create? " -NoNewline -ForegroundColor Yellow
    $users = [int] (Read-Host)

    while($users -gt 0){

        $users--

        $user = Get-Credential -Message "Enter the username and password of the new user"

        if(![bool](Get-ADObject -Filter {sAMAccountname -eq $user.UserName})){

                New-ADUser -Name $user.UserName -AccountPassword $user.Password -EmailAddress ($user.UserName + "@" + $env:userdnsdomain.ToLower()) -Enabled $true
                Write-Host "User"$user.Username"successfully created!" -ForegroundColor Green

        }else{

                Write-Host "AD user" $user.UserName "already exists!" -ForegroundColor Yellow

        }

        Configure-User $user.UserName $myProdGroup $myDevGroup

    }

    Write-Host "How many existing Active Directory users do you want to grant access to AWS to? " -NoNewline -ForegroundColor Yellow
    $users = [int] (Read-Host)

    while($users -gt 0){

        $users--

        Write-Host "Enter the username of the user you want to manage: " -NoNewline -ForegroundColor Yellow
        $user = Read-Host
        
        Configure-User $user $myProdGroup $myDevGroup

    }

}catch{

    Write-Error $_.Exception.Message

}

Stop-Transcript
