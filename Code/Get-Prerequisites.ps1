<#
MindMiner  Copyright (C) 2017-2022  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

function Get-Prerequisites([Parameter(Mandatory)][string] $bin) {
	$prerequisites = [System.Collections.ArrayList]::new()
	$prerequisites.AddRange(@(
		@{ Path="7z.dll"; URI="https://mindminer.online/miners/7z.dll" }
		@{ Path="7z.exe"; URI="https://mindminer.online/miners/7z.exe" }
		@{ Path="FeatureDetector.exe"; URI="https://mindminer.online/miners/FeatureDetector.exe"; SHA="AD27801A087CBF6F4ED1E4026EC86A1218EFFA11CF9AFE4E2BF4BF693DE23470" }
		@{ Path="AMDOpenCLDeviceDetection.exe"; URI="https://mindminer.online/miners/AMDOpenCLDeviceDetection.exe" } # originally https://github.com/nicehash/NiceHashMinerLegacy/tree/master/AMDOpenCLDeviceDetection
		@{ Path="OpenHardwareMonitorLib.dll"; URI="https://github.com/Quake4/openhardwaremonitor/releases/download/0.9.7/OpenHardwareMonitorLib.dll"; SHA="DFC5F1810532CD338569084A6F80899D8E8601592B1B8D1AD8FDEF262EC15C55" } # originally https://github.com/openhardwaremonitor/openhardwaremonitor
	))		
	if ((Test-Path ([Config]::SMIPath)) -eq $false) {
		$prerequisites.AddRange(@(
			@{ Path="nvidia-smi.exe"; URI="https://mindminer.online/miners/nvidia-smi.exe" }
		))
		[Config]::SMIPath = ([IO.Path]::Combine($bin, "nvidia-smi.exe"))
	}
	
	$prerequisites = ($prerequisites | Where-Object {
		$file = [IO.Path]::Combine($bin, $_.Path);
		$exists = Test-Path $file;
		if ($exists -and ![string]::IsNullOrWhiteSpace($_.SHA) -and (Get-FileHash $file -Algorithm sha256).Hash -ne $_.SHA) {
			$exists = $false;
		}
		$exists -eq $false
	})
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