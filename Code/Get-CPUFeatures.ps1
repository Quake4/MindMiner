<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4/Quake3
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

function Get-CPUFeatures([Parameter(Mandatory)][string] $bin) {
	$fn = [IO.Path]::Combine($bin, "FeatureDetector.exe")
	[Diagnostics.Process] $process = $null
	try {
		$pi = [Diagnostics.ProcessStartInfo]::new($fn)
		$pi.UseShellExecute = $false
		$pi.RedirectStandardOutput = $true
		[Diagnostics.Process] $process = [Diagnostics.Process]::Start($pi)
		$process.StandardOutput.ReadLine().Split(@("Features", " ", ":", ","), [StringSplitOptions]::RemoveEmptyEntries)
		Remove-Variable pi
	}
	catch {
		Write-Host "Cannot detect CPU features: $_" -ForegroundColor Red
	}
	finally {
		if ($process) {
			$process.Dispose()
		}
	}
}