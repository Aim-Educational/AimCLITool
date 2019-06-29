if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Unix) {
    throw "Only UNIX is supported right now. Certbot, pls come to windows ;(";
}

Write-Host "### NOTE: If it looks like compliation freezes, just wait. It's probably due to low memory. ###"

$CWD = $(Get-Location)
$OutputFile = [System.IO.Path]::Combine($CWD, "bin", "aim")

& dub build --compiler dmd -b release
& rm "/usr/bin/aim"
& ln $OutputFile "/usr/bin/aim"