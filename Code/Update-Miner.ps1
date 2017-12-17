<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

function Update-Miner([Parameter(Mandatory)][string] $bin) {
	Write-Host "Check for updates ..." -ForegroundColor Green
	$latest = Get-UrlAsJson "https://api.github.com/repos/Quake4/MindMiner/releases/latest"
	if ($latest -and [Config]::Version -ne $latest.tag_name) {
		Write-Host "MindMiner $($latest.tag_name)" -NoNewline -ForegroundColor Cyan
		Write-Host " update found. Downloading ..." -ForegroundColor Green
		$file = @(
			@{ Path="MM.New\LICENSE"; URI="$($latest.zipball_url)" }
		) 
		try {
			Start-Job -Name "update" -ArgumentList $file -FilePath ".\Code\Downloader.ps1" -InitializationScript $BinScriptLocation | Out-Null
			Wait-Job -Name "update" | Out-Null
			Remove-Job -Name "update"
		}
		catch {
			Write-Host "Error downloading update archive: $_." -ForegroundColor Red
		}
		Remove-Variable file
		$true
	}
	else {
		$false
	}
}