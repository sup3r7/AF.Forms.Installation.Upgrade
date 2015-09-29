#
# CopyArtifactsFromTeamCity.ps1
#

try
{
	Copy-Item -Path C:\UpgradeArtifact\*.* -Destination \\NOVFASSRVDEMO\Install
}
catch [System.Net.WebException],[System.Exception]
{
	$errorMessage = $_.Exception.Message;

    Write-Host "Unhandled exception in CopyArtifactsFromTeamCity" -ForegroundColor Red;
    Write-Host "Error message: $errorMessage" -ForegroundColor Red;

	Write-Error "Error message: $errorMessage"
}
finally
{
}