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

.PARAMETER LogFile
Specifies the literal Path to Log file for this script.

.PARAMETER LogLevel
Specifies the Log level for this script: 0 - Debug, 1 - Error, 2 - Warning, 3 - Info (default).

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

# Centrify Tenant URL and OAuth settings
[string]$Url = "aasgaard.my.centrify-dev.net"
[string]$APIClient = "secretserver"
[string]$APIScope = "sync"
[string]$APISecret = "c3ZjX3NlY3JldHNlcnZlckBhYXNnYWFyZC5kZXY6Q2VudHIxZnk="

# Log file and level
[string]$LogFile = "C:\Users\fabrice\Documents\GitHub\centrify-thycotic-vaultsync\centrify_vaultsync.log"
[int32]$LogLevel = 0

# Script arguments
[string]$Action = $Args[0]
[string]$ResourceType = $Args[1]
[string]$ResourceName = $Args[2]
[string]$AccountName = $Args[3]
[string]$Password = $Args[4]
[string]$ComputerClass = $Args[5]

##########################
###    LOG FACILITY    ###
##########################
function Write-Log([int32]$Level, [string]$Message)
{
    # Evaluate Log Level based on global configuration
    if ($Level -ge $LogLevel)
    {
        # Format message
        [string]$Timestamp = Get-Date -Format "yyyy-MM-ddThh:mm:sszzz"
        switch ($Level)
        {
            "0" { [string]$MessageLevel = "DEBUG" }
            "1" { [string]$MessageLevel = "ERROR" }
            "2" { [string]$MessageLevel = "WARN" }
            "3" { [string]$MessageLevel = "INFO" }
        }
        # Write Log
        ("{0}|{1}|{2}" -f $Timestamp, $MessageLevel, $Message) | Out-File -FilePath $LogFile -Append -NoClobber -Force
    }
}

##########################################
###     CENTRIFY POWERSHELL MODULE     ###
##########################################

# Add PowerShell Module to session if not already loaded
[string]$ModuleName = "Centrify.Platform.PowerShell"
# Load PowerShell Module if not already loaded
if (@(Get-Module | Where-Object {$_.Name -eq $ModuleName}).count -eq 0) {
	Write-Log 0 ("Loading {0} module..." -f $ModuleName)
	Import-Module $ModuleName
	if (@(Get-Module | Where-Object {$_.Name -eq $ModuleName}).count -ne 0) {
		Write-Log 0 ("{0} module loaded" -f $ModuleName)
	}
	else {
		Write-Log 1 ("Unable to load {0} module" -f $ModuleName)
        exit 1
	}
}

##########################
###     MAIN LOGIC     ###
##########################

if ($PlatformConnection -eq [void]$null) {
    # Connect to Centrify Platform
    Connect-CentrifyPlatform -Url $Url -Client $APIClient -Scope $APIScope -Secret $APISecret
    if ($PlatformConnection -eq [void]$null) {
        Write-Log 1 ("Unable to establish connection to Centrify tenant '{0}'" -f $Url)
        exit 1
    }
    else {
        Write-Log 0 ("Connection to Centrify tenant '{0}'" -f $Url)
    }
}
else {
    Write-Log 0 ("Connected to Centrify tenant '{0}'" -f $PlatformConnection.PodFqdn)
}

# Evaluate target type to perform action against
switch -Exact ($ResourceType) {
    "server" {
        # Validate Server exists
        Write-Log 0 ("Looking for Target resource '{0}' in tenant '{1}'" -f $ResourceName, $Url)
        $VaultedServer = Get-VaultSystem -Name $ResourceName
        if ($VaultedServer -eq [void]$null) {
            # Evaluate Action to perform
            if ($Action -eq "create") {
                Write-Log 2 ("Target Server '{0}' cannot be found" -f $ResourceName)
                # Create Server in Centrify Vault
                $VaultedServer = New-VaultSystem -Name $ResourceName -Fqdn $ResourceName -ComputerClass $ComputerClass
                Write-Log 3 ("Target Server '{0}' with computer class '{1}' created in Centrify Vault" -f $ResourceName, $ComputerClass)
            }
            else {
                # Server must exists for Update and Delete actions
                Write-Log 1 ("Target Server '{0}' cannot be found" -f $ResourceName)
                exit 1
            }
        }
        # Validate Account exists
        Write-Log 0 ("Looking for Account '{0}' on resource '{1}'" -f $AccountName, $ResourceName)
        $VaultedAccount = Get-VaultAccount -VaultSystem $VaultedServer -User $AccountName
        if ($VaultedAccount -eq [void]$null) {
            # Evaluate Action to perform
            if ($Action -eq "create") {
                Write-Log 2 ("Target Account '{0}' cannot be found in Server '{1}'" -f $AccountName, $ResourceName)
                # Create Account in Centrify Vault
                $VaultedAccount = Add-VaultAccount -VaultSystem $VaultedServer -User $AccountName -Password $Password -IsManaged $False
                Write-Log 3 ("Target Account '{0}' added to Server '{1}' in Centrify Vault" -f $AccountName, $ResourceName)
            }
            else {
                # Account must exists for Update and Delete actions
                Write-Log 1 ("Target Account '{0}' cannot be found in Server '{1}'" -f $AccountName, $ResourceName)
                exit 1
            }
        }
    }

    "domain" {
        # Validate Domain exists
        Write-Log 0 ("Looking for Target resource '{0}' in tenant '{1}'" -f $ResourceName, $Url)
        $VaultedDomain = Get-VaultDomain -Name $ResourceName
        if ($VaultedDomain -eq [void]$null) {
            # Domain must exists for Create, Update and Delete actions
            Write-Log 1 ("Target Domain '{0}' cannot be found" -f $ResourceName)
            exit 1
        }
        # Validate Account exists
        Write-Log 0 ("Looking for Account '{0}' on resource '{1}'" -f $AccountName, $ResourceName)
        $VaultedAccount = Get-VaultAccount -VaultDomain $VaultedDomain -User $AccountName
        if ($VaultedAccount -eq [void]$null) {
            # Evaluate Action to perform
            if ($Action -eq "create") {
                Write-Log 2 ("Target Account '{0}' cannot be found in Domain '{1}'" -f $AccountName, $ResourceName)
                # Create Account in Centrify Vault
                $VaultedAccount = Add-VaultAccount -VaultDomain $VaultedDomain -User $AccountName -Password $Password -IsManaged $False
                Write-Log 3 ("Target Account '{0}' added to Domain '{1}' in Centrify Vault" -f $AccountName, $ResourceName)
            }
            else {
                # Account must exists for Update and Delete actions
                Write-Log 1 ("Target Account '{0}' cannot be found in Domain '{1}'" -f $AccountName, $ResourceName)
            }
        }
    }

    "database" {
        # Validate Database exists
        Write-Log 0 ("Looking for Target resource '{0}' in tenant '{1}'" -f $ResourceName, $Url)
        $VaultedDatabase = Get-VaultDatabase -Name $ResourceName
        if ($VaultedDatabase -eq [void]$null) {
            # Database must exists for Create, Update and Delete actions
            Write-Log 1 ("Target Database '{0}' cannot be found" -f $ResourceName)
            exit 1
        }
        # Validate Account exists
        Write-Log 0 ("Looking for Account '{0}' on resource '{1}'" -f $AccountName, $ResourceName)
        $VaultedAccount = Get-VaultAccount -VaultDatabase $VaultedDatabase -User $AccountName
        if ($VaultedAccount -eq [void]$null) {
            # Evaluate Action to perform
            if ($Action -eq "create") {
                Write-Log 2 ("Target Account '{0}' cannot be found in Database '{1}'" -f $AccountName, $ResourceName)
                # Create Account in Centrify Vault
                $VaultedAccount = Add-VaultAccount -VaultDatabase $VaultedDatabase -User $AccountName -Password $Password -IsManaged $False
                Write-Log 3 ("Target Account '{0}' added to Database '{1}' in Centrify Vault" -f $AccountName, $ResourceName)
            }
            else {
                # Account must exists for Update and Delete actions
                Write-Log 1 ("Target Account '{0}' cannot be found in Database '{1}'" -f $AccountName, $ResourceName)
                exit 1
            }
        }
    }

    <# --- THERE IS NO CMDLET YET FOR CLOUD PROVIDERS ---
    "cloud provider" {
        # Validate CloudProvider exists
        $VaultedCloudProvider = Get-VaultCloudProvider -Name $ResourceName
        if ($VaultedCloudProvider -eq [void]$null) {
            Write-Log 1 ("Target Cloud Provider '{0}' cannot be found" -f $ResourceName)
        }
        # Validate Account exists
        $VaultedAccount = Get-VaultAccount -VaultCloudProvider $VaultedCloudProvider -Name $AccountName
        if ($VaultedAccount -eq [void]$null) {
            Write-Log 1 ("Target Account '{0}' cannot be found in Cloud Provider '{1}'" -f $AccountName, $ResourceName)
        }
    } #>
    
    default {
        Write-Log 1 ("Target Type '{0}' is not supported" -f $ResourceType)
        exit 1
    }
}

# Perform action on Account
if ($Action -eq "update") {
    # Update Account password
    Write-Log 0 ("Updating password for Account '{0}' on resource '{1}'" -f $AccountName, $ResourceName)
    Set-VaultPassword -VaultAccount $VaultedAccount -Password $Password
    Write-Log 3 ("'{0}' Account password updated on resource '{1}'" -f $VaultedAccount.User, $VaultedAccount.Name)
}
elseif ($Action -eq "delete") {
    # Delete Account from Centrify Vault
    Write-Log 0 ("Deleting Account '{0}' from resource '{1}'" -f $AccountName, $ResourceName)
    $VaultedAccount | Remove-VaultAccount
    Write-Log 3 ("'{0}' Account deleted from resource '{1}'" -f $VaultedAccount.User, $VaultedAccount.Name)
}
else {
    # Throw error for any action other than create
    if ($Action -ne "create") {
        Write-Log 1 ("Action '{0}' is not supported" -f $Action)
        exit 1
    }
}
