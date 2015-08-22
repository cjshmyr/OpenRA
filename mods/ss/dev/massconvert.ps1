"Mass Sole Survivor map converter - by cjshmyr"
"Converting maps..."

Get-ChildItem "extracted-patched-maps" -Filter *.ini | `
Foreach-Object{
    "Converting: " + $_.FullName
	& '..\..\..\OpenRA.Utility.exe' cnc --map-import $_.FullName
}

"Moving maps..."
Get-ChildItem -Filter *.oramap | `
Foreach-Object{
	"Moving map: " + $_.FullName
	Move-Item $_.FullName "..\maps\"
}

Read-Host "Done; press any key to close"