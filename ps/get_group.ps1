param (
    [string]$group = "g0070100701UepSupport"
)
$members = Get-ADGroup -Filter {Name -eq $group} | Get-ADGroupMember
foreach ($member in $members) {
    $user = Get-ADUser $member
    Write-Host "$($user.Name) $($user.GivenName) $($user.Surname) ($($user.UserPrincipalName))"
}