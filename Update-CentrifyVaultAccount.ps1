###############################################################################################################
# Update Centrify Vault Account
#
# 
###############################################################################################################

<#
.SYNOPSIS
This script can be used by Secret Server Dependency feature to update account password in Centrify Platform.

.DESCRIPTION
This script takes in number of parameters to successfully update account password in Centrify Platform.

.PARAMETER Url
Specifies the URL of Centrify Platform. For example "abc001.my.centrify.net". Leading "https://" is NOT required.

.PARAMETER APIClient
Specifies the Centrify Platform API Client to use for OAuth.

.PARAMETER APIScope
Specifies the Centrify Platform API Scope to use for OAuth.

.PARAMETER APISecret
Specifies the Centrify Platform API Secret to use for OAuth (Base64 Secret for OAUth Confidential Client authentication).

.PARAMETER Action
Specifies the Action to perform on the Centrify Platform resource. It can be create|update|delete".

.PARAMETER ResourceType
Specifies the Centrify Platform resource type. It can be system|database|domain".

.PARAMETER ResourceName
Specifies the resource name in Centrify Platform. "Name" field of a resource (system, database or domain) in Centrify Platform uniquely identifies a resource. You can create a new field in a template to store this value in Secret Server or make use of Notes field.

.PARAMETER AccountName
Specifies the account name of the resource. "Username" field in a secret should correspond to the username of an account in Centrify Platform.

.PARAMETER Password
Specifies the new password of the account to be updated.

.PARAMETER ComputerClass
Specifies the system resource Computer Class when Action is to create a new system resource. Leave blank in any other cases.

#>

##########################
###     PARAMETERS     ###
##########################

$Url = "aasgaard.my.centrify-dev.net"
$APIClient = "secretserver"
$APIScope = "sync"
$APISecret = "c3ZjX3NlY3JldHNlcnZlckBhYXNnYWFyZC5kZXY6Q2VudHIxZnk="

$Action = $Args[0]
$ResourceType = $Args[1]
$ResourceName = $Args[2]
$AccountName = $Args[3]
$Password = $Args[4]
$ComputerClass = $Args[5]

##########################################
###     CENTRIFY POWERSHELL MODULE     ###
##########################################

# Add PowerShell Module to session if not already loaded
[System.String]$ModuleName = "Centrify.Platform.PowerShell"
# Load PowerShell Module if not already loaded
if (@(Get-Module | Where-Object {$_.Name -eq $ModuleName}).count -eq 0) {
	Write-Verbose ("Loading {0} module..." -f $ModuleName)
	Import-Module $ModuleName
	if (@(Get-Module | Where-Object {$_.Name -eq $ModuleName}).count -ne 0) {
		Write-Verbose ("{0} module loaded." -f $ModuleName)
	}
	else {
		Throw ("ERROR: Unable to load {0} module." -f $ModuleName)
	}
}

##########################
###     MAIN LOGIC     ###
##########################

if ($PlatformConnection -eq [Void]$Null) {
    # Connect to Centrify Platform
    Connect-CentrifyPlatform -Url $Url -Client $APIClient -Scope $APIScope -Secret $APISecret
    if ($PlatformConnection -eq [Void]$Null) {
        Throw ("ERROR: Unable to establish connection to Centrify tenant using URL {0}." -f $Url)
    }
}

# Evaluate target type to perform action against
switch -Exact ($ResourceType) {
    "server" {
        # Validate Server exists
        $VaultedServer = Get-VaultSystem -Name $ResourceName
        if ($VaultedServer -eq [Void]$Null) {
            # Evaluate Action to perform
            if ($Action -eq "create") {
                # Create Server in Centrify Vault
                $VaultedServer = New-VaultSystem -Name $ResourceName -Fqdn $ResourceName -ComputerClass $ComputerClass
            }
            else {
                # Server must exists for Update and Delete actions
                Throw ("ERROR: Target Server '{0}' cannot be found." -f $ResourceName)
            }
        }
        # Validate Account exists
        $VaultedAccount = Get-VaultAccount -VaultSystem $VaultedServer -User $AccountName
        if ($VaultedAccount -eq [Void]$Null) {
            # Evaluate Action to perform
            if ($Action -eq "create") {
                # Create Account in Centrify Vault
                $VaultedAccount = Add-VaultAccount -VaultSystem $VaultedServer -User $AccountName -Password $Password -IsManaged $False
            }
            else {
                # Account must exists for Update and Delete actions
                Throw ("ERROR: Target Account '{0}' cannot be found in Server '{1}'." -f $AccountName, $ResourceName)
            }
        }
    }

    "domain" {
        # Validate Domain exists
        $VaultedDomain = Get-VaultDomain -Name $ResourceName
        if ($VaultedDomain -eq [Void]$Null) {
            # Domain must exists for Create, Update and Delete actions
            Throw ("ERROR: Target Domain '{0}' cannot be found." -f $ResourceName)
        }
        # Validate Account exists
        $VaultedAccount = Get-VaultAccount -VaultDomain $VaultedDomain -User $AccountName
        if ($VaultedAccount -eq [Void]$Null) {
            # Evaluate Action to perform
            if ($Action -eq "create") {
                # Create Account in Centrify Vault
                $VaultedAccount = Add-VaultAccount -VaultDomain $VaultedDomain -User $AccountName -Password $Password -IsManaged $False
            }
            else {
                # Account must exists for Update and Delete actions
                Throw ("ERROR: Target Account '{0}' cannot be found in Domain '{1}'." -f $AccountName, $ResourceName)
            }
        }
    }

    "database" {
        # Validate Database exists
        $VaultedDatabase = Get-VaultDatabase -Name $ResourceName
        if ($VaultedDatabase -eq [Void]$Null) {
            # Database must exists for Create, Update and Delete actions
            Throw ("ERROR: Target Database '{0}' cannot be found." -f $ResourceName)
        }
        # Validate Account exists
        $VaultedAccount = Get-VaultAccount -VaultDatabase $VaultedDatabase -User $AccountName
        if ($VaultedAccount -eq [Void]$Null) {
            # Evaluate Action to perform
            if ($Action -eq "create") {
                # Create Account in Centrify Vault
                $VaultedAccount = Add-VaultAccount -VaultDatabase $VaultedDatabase -User $AccountName -Password $Password -IsManaged $False
            }
            else {
                # Account must exists for Update and Delete actions
                Throw ("ERROR: Target Account '{0}' cannot be found in Database '{1}'." -f $AccountName, $ResourceName)
            }
        }
    }

    <# --- THERE IS NO CMDLET YET FOR CLOUD PROVIDERS ---
    "cloud provider" {
        # Validate CloudProvider exists
        $VaultedCloudProvider = Get-VaultCloudProvider -Name $ResourceName
        if ($VaultedCloudProvider -eq [Void]$Null) {
            Throw ("ERROR: Target Cloud Provider '{0}' cannot be found." -f $ResourceName)
        }
        # Validate Account exists
        $VaultedAccount = Get-VaultAccount -VaultCloudProvider $VaultedCloudProvider -Name $AccountName
        if ($VaultedAccount -eq [Void]$Null) {
            Throw ("ERROR: Target Account '{0}' cannot be found in Cloud Provider '{1}'." -f $AccountName, $ResourceName)
        }
    } #>
    
    default {
        Throw ("ERROR: Target Type '{0}' is not supported." -f $ResourceType)
    }
}

# Perform action on Account
if ($Action -eq "update") {
    # Update Account password
    Set-VaultPassword -VaultAccount $VaultedAccount -Password $Password
}
elseif ($Action -eq "delete") {
    # Delete Account from Centrify Vault
    $VaultedAccount | Remove-VaultAccount
}
else {
    # Throw error for any action other than create
    if ($Action -ne "create") {
        Throw ("ERROR: Action '{0}' is not supported." -f $Action)
    }
}
