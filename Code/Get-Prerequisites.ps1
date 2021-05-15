<#
MindMiner  Copyright (C) 2017-2021  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

function Get-Prerequisites([Parameter(Mandatory)][string] $bin) {
	$prerequisites = [System.Collections.ArrayList]::new()
	$prerequisites.AddRange(@(
		@{ Path="7z.dll"; URI="http://mindminer.online/miners/7z.dll" }
		@{ Path="7z.exe"; URI="http://mindminer.online/miners/7z.exe" }
		@{ Path="FeatureDetector.exe"; URI="http://mindminer.online/miners/FeatureDetector.exe" }
		@{ Path="AMDOpenCLDeviceDetection.exe"; URI="http://mindminer.online/miners/AMDOpenCLDeviceDetection.exe" } # originally https://github.com/nicehash/NiceHashMinerLegacy/tree/master/AMDOpenCLDeviceDetection
		# @{ Path="OverdriveN.exe"; URI="http://mindminer.online/miners/OverdriveN.exe" } # originally https://github.com/tutulino/Megaminer/blob/master/OverdriveN.exe
		@{ Path="OpenHardwareMonitorLib.dll"; URI="http://mindminer.online/miners/OpenHardwareMonitorLib.dll" } # originally https://github.com/openhardwaremonitor/openhardwaremonitor
	))		
	if ((Test-Path ([Config]::SMIPath)) -eq $false) {
		$prerequisites.AddRange(@(
			@{ Path="nvidia-smi.exe"; URI="http://mindminer.online/miners/nvidia-smi.exe" }
		))
		[Config]::SMIPath = ([IO.Path]::Combine($bin, "nvidia-smi.exe"))
	}
	
	$prerequisites = ($prerequisites | Where-Object { (Test-Path ([IO.Path]::Combine($bin, $_.Path))) -eq $false })
	if ($prerequisites.Length -gt 0) {
		Write-Host "Download $($prerequisites.Length) prerequisite(s) ..." -ForegroundColor Green
		try {
			Start-Job -Name "Prerequisites" -ArgumentList $prerequisites -FilePath "Code\Downloader.ps1" -InitializationScript $BinScriptLocation | Out-Null
			Wait-Job -Name "Prerequisites" | Out-Null
			Remove-Job -Name "Prerequisites"
		}
		catch {
			Write-Host "Error downloading prerequisites: $_." -ForegroundColor Red
			$Config = $null
		}
	}
	Remove-Variable prerequisites
}