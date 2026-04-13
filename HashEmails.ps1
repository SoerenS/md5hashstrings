[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, HelpMessage="Filename or path to the source email list.")]
    [string]$InputFile,

    [Parameter(Mandatory=$true, HelpMessage="Filename or path where the hashes will be saved.")]
    [string]$OutputFile,

    [Parameter(Mandatory=$true, HelpMessage="The secret salt/key to append to the emails.")]
    [string]$SaltKey
)

process {
    # Resolve paths relative to the script location
    $fullInputPath = if ([System.IO.Path]::IsPathRooted($InputFile)) { $InputFile } else { Join-Path $PSScriptRoot $InputFile }
    $fullOutputPath = if ([System.IO.Path]::IsPathRooted($OutputFile)) { $OutputFile } else { Join-Path $PSScriptRoot $OutputFile }

    if (Test-Path $fullInputPath) {
        Write-Host "Reading: $fullInputPath" -ForegroundColor Cyan
        
        # 1. Count lines for progress bar
        Write-Host "Analyzing file size..." -ForegroundColor Gray
        $totalLines = [System.IO.File]::ReadAllLines($fullInputPath).Length
        $currentLine = 0

        # 2. Initialize Crypto and IO
        $md5 = [System.Security.Cryptography.MD5]::Create()
        $utf8 = [System.Text.Encoding]::UTF8
        
        # Open a stream for writing (Efficient for large files)
        $writer = New-Object System.IO.StreamWriter($fullOutputPath)

        Write-Host "Hashing emails..." -ForegroundColor Cyan

        # 3. Process
        foreach ($line in [System.IO.File]::ReadLines($fullInputPath)) {
            $currentLine++
            
            # Update progress bar every 500 lines for maximum speed
            if ($currentLine % 500 -eq 0 -or $currentLine -eq $totalLines) {
                $percent = ($currentLine / $totalLines) * 100
                Write-Progress -Activity "Hashing Emails" `
                               -Status "Processing line $currentLine of $totalLines" `
                               -PercentComplete $percent
            }

            $email = $line.Trim()
            if ($email -ne "") {
                # Combine and hash
                $combinedString = $email + $SaltKey
                $bytes = $utf8.GetBytes($combinedString)
                $hashBytes = $md5.ComputeHash($bytes)
                
                # Convert to hex
                $hashString = [System.BitConverter]::ToString($hashBytes).Replace("-", "").ToLower()
                
                # Write to the file on a new line
                $writer.WriteLine($hashString)
            }
        }
        
        # 4. Cleanup
        $writer.Close()
        $writer.Dispose()
        $md5.Dispose()
        
        Write-Progress -Activity "Hashing Emails" -Completed
        Write-Host "`nSuccess! Processed $totalLines lines." -ForegroundColor Green
        Write-Host "Output file: $fullOutputPath" -ForegroundColor Gray
    } else {
        Write-Error "The input file '$fullInputPath' could not be found."
    }
}