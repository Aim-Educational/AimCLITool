if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Unix) {
    throw "Only UNIX is supported right now. Certbot, pls come to windows ;(";
}

$CWD = $(Get-Location)
$OutputFile = [System.IO.Path]::Combine($CWD, "bin", "aim")

& dub build
& rm "/usr/bin/aim"
& ln $OutputFile "/usr/bin/aim"