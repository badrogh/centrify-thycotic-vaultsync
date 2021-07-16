# Centrify-Thycotic "Vault Sync" tools
These scripts take in number of parameters to successfully update objects in Centrify Platform.

# Configuration
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

# To Do
- Document OAuth2 setup on Centrify side (App should be named "SecretServer" by default and use a restricted scope as requires SysAdmin privileges)
- Add Logging capability to scripts (write events into Log file with preset Log level)
- Script cannot support renaming of secrets or systems, must implement UUID/SecretID storage on one side or the other to allow unique mapping)
- May need to implement missing Cmdlets in Centrify SDK: New-VaultDomain, New-VaultDatabase, New-VaultCloudProvider, Get-VaultCloudProvider, Set-VaultCloudProvider
- Centrify Service User for Secret Server should be granted Global permissions on Accounts and System to guarantee rights to manage accounts. Permissions would also need to be granted for ALL databases and domains if planned to be used this way (no Global permissions available for those)