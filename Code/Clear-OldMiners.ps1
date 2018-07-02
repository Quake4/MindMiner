<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

function Clear-OldMiners ([object[]] $activeMiners) {
	Write-Host "Clear old miners ..." -ForegroundColor Green
	try {
		$latestminers = Get-UrlAsJson "https://api.github.com/repos/Quake4/MindMiner/contents/Miners?ref=$([Config]::Version)" | ForEach-Object { $_.name.Replace(".ps1", [string]::Empty) }
		# check miners folder
		if ($latestminers) {
			$clearminers = Get-ChildItem ([Config]::MinersLocation) | Where-Object Extension -eq ".ps1" | ForEach-Object { $_.Name.Replace(".ps1", [string]::Empty) } |
				Where-Object { $latestminers -notcontains $_ -and $activeMiners -notcontains $_ }  | ForEach-Object { "$_"; }
			# check bin folder
			$clearminers += (Get-ChildItem ([Config]::BinLocation) -Directory | Where-Object { $latestminers -notcontains $_.Name -and $activeMiners -notcontains $_.Name -and $clearminers -notcontains $_.Name } | ForEach-Object { $_.Name; })
			# check for delete
			if (!$clearminers -or $clearminers.Length -eq 0) {
				Write-Host "Nothing to delete." -ForegroundColor Yellow
			}
			else {
				# remove loop
				$clearminers | ForEach-Object {
					# remove after ask
					if (Get-Question "Remove miner '$_'") {
						# remove miner
						$path = "$([Config]::MinersLocation)\$_.ps1"
						if ((Test-Path $path -PathType Leaf)) {
							Remove-Item $path -Force
						}
						# remove bin
						$path = "$([Config]::BinLocation)\$_"
						if ((Test-Path $path -PathType Container)) {
							Remove-Item $path -Recurse -Force
						}
						# remove stat
						$path = "$([Config]::StatsLocation)\$_.txt"
						if ((Test-Path $path -PathType Leaf)) {
							Remove-Item $path -Force
						}
					}
				}
				Write-Host "Miners deleted." -ForegroundColor Yellow
			}
		}
	}
	catch {
		Write-Host "Error: $_" -ForegroundColor Red
	}
}