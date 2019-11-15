param (
    [string]$id = "",
    [string]$email = ""
)
if ($email -gt "") {
    Get-ADUser -Filter {Emailaddress -eq $email}
} elseif ($id -gt "") {
    Get-ADUser -Filter {Name -eq $id}
} else {
    Write-Host "must use either the -id or -email commandline parameters"
}
