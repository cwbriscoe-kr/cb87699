param (
    [string]$group = "g0070100701UepSupport",
    [string]$server = "LDAP://kroger.com:3268"
)
$sSearchStr = "(&(objectCategory=group)(name=" + $group + "))"
$oSearch = New-Object directoryservices.DirectorySearcher($oADRoot, $sSearchStr)
$oFindResult = $oSearch.FindAll()
$oGroup = New-Object System.DirectoryServices.DirectoryEntry($oFindResult.Path)
Foreach ($mem in $oGroup.Member) {
    $oMember = New-Object System.DirectoryServices.DirectoryEntry($server + "/" + $mem)
    $memberList += $oMember.Name
}
Write-Host ($memberList | Sort-Object)