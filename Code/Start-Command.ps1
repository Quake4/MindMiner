<#
MindMiner  Copyright (C) 2018-2022  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

function Start-Command ([string] $runlocation, [string] $cmdline, [int] $timeout) {
	if (![string]::IsNullOrWhiteSpace($cmdline)) {
		# create Run folder
		if (!(Test-Path $runlocation)) {
			New-Item -ItemType Directory $runlocation | Out-Null
		}
		# magic
		$cmdline = $cmdline.Trim()
		[string] $command = [string]::Empty
		[string] $arg = $null
		if ($cmdline[0] -eq '"') {
			$pos = $cmdline.IndexOf('"', 1)
			if ($pos -gt 1) {
				$command = $cmdline.Substring(0, $pos + 1)
				if ($pos + 1 -eq $cmdline.Length) {
					$cmdline = [string]::Empty
				}
				elseif ($cmdline[$pos + 1] -eq ' ') {
					$arg = $cmdline.Remove(0, $pos + 2)
					$cmdline = [string]::Empty
				}
				else {
					$cmdline = $cmdline.Remove(0, $pos + 1)
				}
			}
		}
		$split = $cmdline.Split(@(' '), 2, [StringSplitOptions]::RemoveEmptyEntries)
		if ($split.Length -ge 1) {
			$command += $split[0]
			if ($split.Length -eq 2) {
				$arg = $split[1] 
			}
		}
		# show and start command
		if ([string]::IsNullOrWhiteSpace($arg)) {
			Write-Host "Run command '$command'" -ForegroundColor Yellow
			try {
				Start-Process $command -WindowStyle Minimized -WorkingDirectory $runlocation -Wait
			}
			catch {
				Write-Host $_ -ForegroundColor Red
				Start-Sleep -Seconds $timeout
			}
		}
		else {
			Write-Host "Run command '$command' with arguments '$arg'" -ForegroundColor Yellow
			try {
				Start-Process $command $arg -WindowStyle Minimized -WorkingDirectory $runlocation -Wait
			}
			catch {
				Write-Host $_ -ForegroundColor Red
				Start-Sleep -Seconds $timeout
			}
		}
	}
}