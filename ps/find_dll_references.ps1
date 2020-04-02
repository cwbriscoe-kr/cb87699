$appFilePath  = "C:\temp\dll.csv"

$scanPath     = 'C:\'

$exefile      = "*.exe"

$dllFile      = "*.dll"

$dll = Get-ChildItem -ErrorAction SilentlyContinue -Recurse -Path $scanPath -Include @($exefile, $dllFile)

$dll | Select-String "msxml4.dll" -ErrorAction SilentlyContinue | Group-Object $($_.name) | Select-Object name | export-csv -path $appFilePath`