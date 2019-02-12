<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

function Select-ActiveTypes ([eMinerType[]] $types) {
	Write-Host "Select active types ..." -ForegroundColor Green
	try {
		$result = [Collections.Generic.List[string]]::new()
		do {
			$result.Clear();
			$types | ForEach-Object {
				if (Get-Question "Use '$_' type device(s)") {
					$result.Add($_)
				}
			}
		} while ($result.Length -le 1)
		$result.ToArray()
		Write-Host "Active types selected." -ForegroundColor Yellow
	}
	catch {
		Write-Host "Error: $_" -ForegroundColor Red
	}
}