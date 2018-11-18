<#
MindMiner  Copyright (C) 2017-2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

function Get-ProcessOutput ([Parameter(Mandatory)][string] $path, [string] $arg) {
	[Diagnostics.Process] $process = $null
	try {
		$pi = [Diagnostics.ProcessStartInfo]::new($path)
		$pi.UseShellExecute = $false
		$pi.RedirectStandardOutput = $true
		if (![string]::IsNullOrWhiteSpace($arg)) {
			$pi.Arguments = $arg
		}
		[Diagnostics.Process] $process = [Diagnostics.Process]::Start($pi)
		return [string]::Join([environment]::NewLine, $process.StandardOutput.ReadToEnd())
	}
	catch {
		Write-Host "Can't run $path`: $_" -ForegroundColor Red
	}
	finally {
		if ($process) {
			$process.Dispose()
		}
	}
}