###############################################################################################################
# Update Centrify Vault Account
#
# 
###############################################################################################################

param
(
	[Parameter(Mandatory = $false, HelpMessage = "Specify the Centrify Platform URL.")]
	[System.String]$Url = "https://aasgaard.my.centrify-dev.net/",

	[Parameter(Mandatory = $false, HelpMessage = "Specify the API Client ID to connect to Centrify Platform using OAuth2.")]
	[System.String]$APIClient = "secretserver",

	[Parameter(Mandatory = $false, HelpMessage = "Specify the API Scope to connect to Centrify Platform using OAuth2.")]
	[System.String]$APIScope = "sync",

    [Parameter(Mandatory = $false, HelpMessage = "Specify the API Secret to connect to Centrify Platform using OAuth2.")]
	[System.String]$APISecret = "c3ZjX3NlY3JldHNlcnZlckBhYXNnYWFyZC5kZXY6Q2VudHIxZnk=",

	[Parameter(Mandatory = $true, Position = 0, HelpMessage = "Specify the action to perform.")]
	[Alias("a")]
	[System.String]$Action,

    [Parameter(Mandatory = $true, Position = 1, HelpMessage = "Specify the account target name in Centrify Platform.")]
	[Alias("t")]
	[System.String]$Target,

    [Parameter(Mandatory = $true, Position = 2, HelpMessage = "Specify the account target type in Centrify Platform.")]
	[Alias("y")]
	[System.String]$TargetType,

	[Parameter(Mandatory = $true, Position = 3, HelpMessage = "Specify the account user name in Centrify Platform.")]
	[Alias("u")]
	[System.String]$UserName,

	[Parameter(Mandatory = $false, HelpMessage = "Specify the account password to set in Centrify Platform.")]
	[Alias("p")]
	[System.String]$Password,

	[Parameter(Mandatory = $false, HelpMessage = "Specify the Computer Class for System creation in Centrify Platform.")]
	[Alias("c")]
	[System.String]$ComputerClass
)

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
		Throw "Unable to load PowerShell module."
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
switch -Exact ($TargetType) {
    "server" {
        # Validate Server exists
        $VaultedServer = Get-VaultSystem -Name $Target
        if ($VaultedServer -eq [Void]$Null) {
            # Evaluate Action to perform
            if ($Action -eq "create") {
                # Create Server in Centrify Vault
                $VaultedServer = New-VaultSystem -Name $Target -Fqdn $Target -ComputerClass $ComputerClass
            }
            else {
                # Server must exists for Update and Delete actions
                Throw ("ERROR: Target Server '{0}' cannot be found." -f $Target)
            }
        }
        # Validate Account exists
        $VaultedAccount = Get-VaultAccount -VaultSystem $VaultedServer -Name $UserName
        if ($VaultedAccount -eq [Void]$Null) {
            # Evaluate Action to perform
            if ($Action -eq "create") {
                # Create Account in Centrify Vault
                $VaultedAccount = Add-VaultAccount -VaultSystem $Target -User $UserName -Password $Password -IsManaged $False
            }
            else {
                # Account must exists for Update and Delete actions
                Throw ("ERROR: Target Account '{0}' cannot be found in Server '{1}'." -f $Username, $Target)
            }
        }
    }

    "domain" {
        # Validate Domain exists
        $VaultedDomain = Get-VaultDomain -Name $Target
        if ($VaultedDomain -eq [Void]$Null) {
            # Domain must exists for Create, Update and Delete actions
            Throw ("ERROR: Target Domain '{0}' cannot be found." -f $Target)
        }
        # Validate Account exists
        $VaultedAccount = Get-VaultAccount -VaultDomain $VaultedDomain -Name $UserName
        if ($VaultedAccount -eq [Void]$Null) {
            # Evaluate Action to perform
            if ($Action -eq "create") {
                # Create Account in Centrify Vault
                $VaultedAccount = Add-VaultAccount -VaultDomain $VaultedDomain -User $UserName -Password $Password -IsManaged $False
            }
            else {
                # Account must exists for Update and Delete actions
                Throw ("ERROR: Target Account '{0}' cannot be found in Domain '{1}'." -f $Username, $Target)
            }
        }
    }

    "database" {
        # Validate Database exists
        $VaultedDatabase = Get-VaultDatabase -Name $Target
        if ($VaultedDatabase -eq [Void]$Null) {
            # Database must exists for Create, Update and Delete actions
            Throw ("ERROR: Target Database '{0}' cannot be found." -f $Target)
        }
        # Validate Account exists
        $VaultedAccount = Get-VaultAccount -VaultDatabase $VaultedDatabase -Name $UserName
        if ($VaultedAccount -eq [Void]$Null) {
            # Evaluate Action to perform
            if ($Action -eq "create") {
                # Create Account in Centrify Vault
                $VaultedAccount = Add-VaultAccount -VaultDatabase $VaultedDatabase -User $UserName -Password $Password -IsManaged $False
            }
            else {
                # Account must exists for Update and Delete actions
                Throw ("ERROR: Target Account '{0}' cannot be found in Database '{1}'." -f $Username, $Target)
            }
        }
    }

    <# --- THERE IS NO CMDLET YET FOR CLOUD PROVIDERS ---
    "cloud provider" {
        # Validate CloudProvider exists
        $VaultedCloudProvider = Get-VaultCloudProvider -Name $Target
        if ($VaultedCloudProvider -eq [Void]$Null) {
            Throw ("ERROR: Target Cloud Provider '{0}' cannot be found." -f $Target)
        }
        # Validate Account exists
        $VaultedAccount = Get-VaultAccount -VaultCloudProvider $VaultedCloudProvider -Name $UserName
        if ($VaultedAccount -eq [Void]$Null) {
            Throw ("ERROR: Target Account '{0}' cannot be found in Cloud Provider '{1}'." -f $Username, $Target)
        }
    } #>
    
    default {
        Throw ("ERROR: Target Type '{0}' is not supported." -f $TargetType)
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
    Throw ("ERROR: Action '{0}' is not supported." -f $Action)
}
