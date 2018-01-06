<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

function Get-AMDPlatformId([Parameter(Mandatory)][string] $bin) {
	[int] $result = -1
	$fn = [IO.Path]::Combine($bin, "AMDOpenCLDeviceDetection.exe")
	[Diagnostics.Process] $process = $null
	try {
		$pi = [Diagnostics.ProcessStartInfo]::new($fn)
		$pi.UseShellExecute = $false
		$pi.RedirectStandardOutput = $true
		[Diagnostics.Process] $process = [Diagnostics.Process]::Start($pi)
		$json = $process.StandardOutput.ReadLine() | ConvertFrom-Json
		$json | ForEach-Object {
			if ($_.PlatformName.ToLowerInvariant().Contains("amd")) {
				$result = $_.PlatformNum
			}
		}
		Remove-Variable json, pi
	}
	catch {
		Write-Host "Cannot detect AMD Platform Id: $_" -ForegroundColor Red
	}
	finally {
		if ($process) {
			$process.Dispose()
		}
	}
	$result
}