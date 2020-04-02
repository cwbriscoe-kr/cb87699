param (
    [string]$id = ""
)
if ($id -gt "") {
    Get-ADPrincipalGroupMembership $id | select name
}
else {
    Write-Host "you must specify the -id commandline parameter"
}