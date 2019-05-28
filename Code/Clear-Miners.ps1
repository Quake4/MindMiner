<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

function Clear-OldMiners ([object[]] $activeMiners) {
	Write-Host "Clean miners ..." -ForegroundColor Green
	try {
		$latestminers = Get-UrlAsJson "https://api.github.com/repos/Quake4/MindMiner/contents/Miners?ref=$([Config]::Version)" | ForEach-Object { $_.name.Replace(".ps1", [string]::Empty) }
		# check miners folder
		if ($latestminers) {
			$clearminers = Get-ChildItem ([Config]::MinersLocation) | Where-Object Extension -eq ".ps1" | ForEach-Object { $_.Name.Replace(".ps1", [string]::Empty) } |
				Where-Object { $latestminers -notcontains $_ -and $activeMiners -notcontains $_ }  | ForEach-Object { "$_"; }
			if ($clearminers -is [string]) {
				$clearminers = @($clearminers)
			}
			# check bin folder
			$clearminers += (Get-ChildItem ([Config]::BinLocation) -Directory | Where-Object { $latestminers -notcontains $_.Name -and $activeMiners -notcontains $_.Name -and $clearminers -notcontains $_.Name } | ForEach-Object { $_.Name; })
			# check for delete
			if (!$clearminers -or $clearminers.Length -eq 0) {
				Write-Host "Nothing to clean." -ForegroundColor Yellow
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
						# remove miner config
						$path = "$([Config]::MinersLocation)\$_.config.txt"
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
						# remove power stat
						$path = "$([Config]::StatsLocation)\$_.power.txt"
						if ((Test-Path $path -PathType Leaf)) {
							Remove-Item $path -Force
						}
					}
				}
				Write-Host "Miners cleaned." -ForegroundColor Yellow
			}
		}
	}
	catch {
		Write-Host "Error: $_" -ForegroundColor Red
	}
}

function Clear-OldMinerStats (
	[Parameter(Mandatory)] $AllMiners,
	[Parameter(Mandatory)] $Statistics,
	[Parameter(Mandatory)] [string] $Interval) {
	($AllMiners | ForEach-Object { $_.Miner.Name } | Select-Object -Unique) | ForEach-Object {
		$Statistics.DelValues($_, $Interval);
	}
}

function Clear-FailedMiners ([object[]] $failedMiners) {
	[bool] $result = $false
	Write-Host "Clean failed miners ..." -ForegroundColor Green
	if (!$failedMiners -or $failedMiners.Length -eq 0) {
		Write-Host "Nothing to clean." -ForegroundColor Yellow
	}
	else {
		$failedMiners | ForEach-Object {
			if (Get-Question "Remove failed state from algorithm '$($_.Miner.Algorithm)' and miner '$($_.Miner.Name)'") {
				$_.ResetFailed();
				$result = $true;
			}
		}
		Write-Host "Miners cleaned." -ForegroundColor Yellow
	}
	$result
}