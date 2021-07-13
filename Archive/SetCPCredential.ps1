<#
.SYNOPSIS
This script can be used by Secret Server Dependence feature to update account password in Centrify Platform.

.DESCRIPTION
This script takes in number of parameters to successfully update account password in Centrify Platform.

Configuration at Secret Server Web server or distributed engine:
1. On the Windows machine where PowerShell is run, install Centrify Platform PowerShell SDK https://github.com/centrify/powershell-sdk

Configuration at Centrify Platform:
1. Create a service account that has sufficient permissions to update password of the accounts in question. This service account is used by the script to authenticate against Centrify Platform.
2. Create a OAuth2 web application with confidential client type. For details, refer to https://github.com/centrify/centrifycli/wiki/Configuring-Centrify-Service-OAuth-for-Centrify-CLI
3. Assign service account the "Run" permission to OAuth2 web application
4. Create necessary system/database/domain accounts that are to be updated by this script and make sure they are not managed by Centrify Platform 

Configuration at Secret Server:
1. Perform necessary configurations to allow PowerShell script to be run properly either in web server or distributed engine. https://docs.thycotic.com/ss/10.9.0/api-scripting/configuring-winrm-powershell
1. Create a dependency script with this content
3. Create a secret that vaults Centrify Platform service account
4. Create or update existing secret(s) to add Centrify Platform service account as associated secret
5. Add a new dependency to run the script with arguments examples like this:
	Ex:
    "<Centrify Platform URL>" "$[1]$USERNAME" "$[1]$PASSWORD" "<OAuth2 AppID>" "<OAuth2 Scope>" system "$MACHINE" "$USERNAME" "$PASSWORD"
	"<Centrify Platform URL>" "$[1]$USERNAME" "$[1]$PASSWORD" "<OAuth2 AppID>" "<OAuth2 Scope>" database "$SERVER" "$USERNAME" "$PASSWORD"
	"<Centrify Platform URL>" "$[1]$USERNAME" "$[1]$PASSWORD" "<OAuth2 AppID>" "<OAuth2 Scope>" domain "$DOMAIN" "$USERNAME" "$PASSWORD"

.PARAMETER Url
Specifies the URL of Centrify Platform. For example "abc001.my.centrify.net". Leading "https://" is NOT required.

.PARAMETER CPASAdmin
Specifies the Centrify Platform service account name.

.PARAMETER CPASPassword
Specifies the Centrify Platform service account password.

.PARAMETER AppID
Specifies the OAuth web application ID in Centrify Platform.

.PARAMETER Scope
Specifies the OAuth web application scope in Centrify Platform.

.PARAMETER ResourceType
Specifies the Centrify Platform resource type. It can be system|database|domain".

.PARAMETER ResourceName
Specifies the resource name in Centrify Platform. "Name" field of a resource (system, database or domain) in Centrify Platform uniquely identifies a resource. You can create a new field in a template to store this value in Secret Server or make use of Notes field.

.PARAMETER AccountName
Specifies the account name of the resource. "Username" field in a secret should correspond to the username of an account in Centrify Platform.

.PARAMETER Password
Specifies the new password of the account to be updated.

#>

Import-Module Centrify.Platform.PowerShell
#$DebugPreference = "Continue"

 
$Url = $Args[0]
$CPASAdmin = $Args[1]
$CPASPassword = $Args[2]
$AppID = $Args[3]
$Scope = $Args[4]

$ResourceType = $Args[5]
$ResourceName = $Args[6]
$AccountName = $Args[7]
$NewPassword = $Args[8]

Write-Debug "Url: $Url"
Write-Debug "CPASAdmin: $CPASAdmin"
Write-Debug "CPASPassword: xxxxxxxx"
Write-Debug "AppID: $AppID"
Write-Debug "Scope: $Scope"
Write-Debug "ResourceType: $ResourceType"
Write-Debug "ResourceName: $ResourceName"
Write-Debug "AccountName: $AccountName"
Write-Debug "NewPassword: xxxxxxxx"

function Get-Base64
{
    param(
        [Parameter(Mandatory=$true, HelpMessage = "Specify the OAuth2 confidential client name.")]
        [System.String]$Client,
        
        [Parameter(Mandatory=$true, HelpMessage = "Specify the OAuth2 confidential client password.")]
		[System.String]$Password		
    )

    # Combine ClientID and Password then encode authentication string in Base64
    $AuthenticationString = ("{0}:{1}" -f $Client, $Password)
    $Secret = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($AuthenticationString))

    # Return Base64 encoded secret
    return $Secret
}

function Update-CPCredential
{
    param (
        [Parameter(Mandatory = $true, HelpMessage = "The URL of Centrify Platform.")]
	    [System.String]$Url,

        [Parameter(Mandatory = $true, HelpMessage = "Centrify Platform service account name.")]
	    [System.String]$CPASAdmin,

        [Parameter(Mandatory = $true, HelpMessage = "Centrify Platform service account password.")]
	    [System.String]$CPASPassword,

        [Parameter(Mandatory = $true, HelpMessage = "OAuth web application ID in Centrify Platform.")]
	    [System.String]$AppID,

        [Parameter(Mandatory = $true, HelpMessage = "OAuth web application scope in Centrify Platform.")]
	    [System.String]$Scope,

        [Parameter(Mandatory = $true, HelpMessage = "Centrify Platform resource type. It can be system|database|domain")]
        [ValidateSet("system","database","domain")]
        [System.String]$ResourceType,

        [Parameter(Mandatory = $true, HelpMessage = "Resource name in Centrify Platform.")]
	    [System.String]$ResourceName,

        [Parameter(Mandatory = $true, HelpMessage = "Account name of the resource.")]
	    [System.String]$AccountName,
    
        [Parameter(Mandatory = $true, HelpMessage = "Password of the account.")]
	    [System.String]$Password
    )

    $Secret = Get-Base64 -Client $CPASAdmin -Password $CPASPassword

    try {
        Connect-CentrifyPlatform -Url $Url -Client $AppID -Scope $Scope -Secret $Secret
        Write-Debug "Connected to Centrify Platform"
    } catch {
        Write-Debug "Failed to connect to Centrify Platform: $($PSItem.ToString())"
        throw $PSItem.ScriptStackTrace
    }

    try {
        switch -Exact ($ResourceType)
        {
            'system'
            {
                $TheResource = Get-VaultSystem -Name $ResourceName
                $TheAccount = Get-VaultAccount -User $AccountName -VaultSystem $TheResource
                Break
            }
            'database'
            {
                $TheResource = Get-VaultDatabase -Name $ResourceName
                $TheAccount = Get-VaultAccount -User $AccountName -VaultDatabase $TheResource
                Break
            }
            'domain'
            {
                $TheResource = Get-VaultDomain -Name $ResourceName
                $TheAccount = Get-VaultAccount -User $AccountName -VaultDomain $TheResource
                Break
            }
        }
        Set-VaultPassword -VaultAccount $TheAccount -Password $Password
        Write-Debug "$AccountName credential on $ResourceName has been updated successfully"
    } catch {
        Write-Debug "Failed to update credential $AccountName on $ResourceName"
        throw $_.ScriptStackTrace
    }
}

Update-CPCredential -Url $Url -CPASAdmin $CPASAdmin -CPASPassword $CPASPassword -AppID $AppID -Scope $Scope -ResourceType $ResourceType -ResourceName $ResourceName -AccountName $AccountName -Password $NewPassword
