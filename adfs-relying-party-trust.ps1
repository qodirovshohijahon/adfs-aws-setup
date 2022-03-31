# .\add_relying_trust.ps1 <relying_party_trust_friendly_name> <atlassian_application_host>

param($Name,$AppHost,$SingleLogout)

If ($SingleLogout) {
	$SingleLogout = "?slo"
}
Else {
	$SingleLogout = ""
}

$IssuanceRules = '@RuleTemplate = "LdapClaims"
 @RuleName = "NameID Name Email"
 c:[Type == "http://schemas.microsoft.com/ws/2008/06/identity/claims/windowsaccountname", Issuer == "AD AUTHORITY"]
  => issue(store = "Active Directory", types = ("http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier",
 "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name",
 "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"), 
 query = ";sAMAccountName,displayName,mail;{0}", param = c.Value); '

$partyTrust = Get-AdfsRelyingPartyTrust `
	-PrefixIdentifier "https://$AppHost/plugins/servlet/samlsso/metadata"


If ($partyTrust) {
	Write-host "There is a record for that relying party already. Do you want it to be removed automatically?" -ForegroundColor Yellow 
    $Readhost = Read-Host " ( y / n ) " 
    Switch ($ReadHost) 
     { 
       Y {Write-host "Removing existing record."; $RemoveExistingTrust=$true} 
       N {Write-Host "Aborting script. Please remove or edit the existing record yourself."; } 
       Default {Write-Host "Aborting script, no option provided."; } 
     } 

	If ($RemoveExistingTrust) {
		Remove-AdfsRelyingPartyTrust `
			-TargetRelyingParty $partyTrust
	}
	Else {
		Exit
	}
}


Add-AdfsRelyingPartyTrust `
	-Name "$Name" `
	-MetadataUrl "https://$AppHost/plugins/servlet/samlsso/metadata$SingleLogout" `
	-AccessControlPolicyName "Permit Everyone" `
	-MonitoringEnabled $true `
	-AutoUpdateEnabled $true `
	-IssuanceTransformRules $IssuanceRules
