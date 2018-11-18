<#
MindMiner  Copyright (C) 2017-2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

function Get-CPUFeatures([Parameter(Mandatory)][string] $bin) {
	try {
		[string] $line = Get-ProcessOutput ([IO.Path]::Combine($bin, "FeatureDetector.exe"))
		$line.Split(@("Features", " ", ":", ",", [environment]::NewLine), [StringSplitOptions]::RemoveEmptyEntries)
	}
	catch {
		Write-Host "Cannot detect CPU features: $_" -ForegroundColor Red
	}
}