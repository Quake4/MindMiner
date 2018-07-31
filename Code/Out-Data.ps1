<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

function Out-Iam ([string] $version) {
	Write-Host "MindMiner $version" -NoNewline -ForegroundColor Cyan
	Write-Host " (C) 2017-$([datetime]::Now.Year) by Oleg Samsonov aka Quake4" -ForegroundColor White
	Write-Host
}

function Out-Header {
	Out-Iam ([Config]::Version.Replace("v", [string]::Empty))
	Write-Host "Help, information and other see on " -NoNewline
	Write-Host "https://github.com/Quake4/MindMiner" -ForegroundColor Green
	Write-Host
	Write-Host "Configuration:" -ForegroundColor Yellow
	Write-Host $Config
}

function Out-Footer {
	Write-Host "Information:" -ForegroundColor Yellow
	Write-Host $Summary
	Write-Host
	Write-Host "Ctrl|Alt+C|Q|Ex" -NoNewline -ForegroundColor Yellow
	Write-Host "it, " -NoNewline
	Write-Host "Ctrl+R" -NoNewline -ForegroundColor Yellow
	Write-Host "estart, " -NoNewline
	Write-Host "S" -NoNewline -ForegroundColor Yellow
	Write-Host "witching mode $($Config.Switching), " -NoNewline
	Write-Host "V" -NoNewline -ForegroundColor Yellow
	Write-Host "erbose level $($Config.Verbose)" -NoNewline
	if ($global:HasConfirm -eq $false -and $global:NeedConfirm -eq $false -and [Config]::UseApiProxy -eq $false) {
		Write-Host ", On/Off " -NoNewline
		Write-Host "P" -NoNewline -ForegroundColor Yellow
		Write-Host "ools" -NoNewline
	}
	Write-Host ", Delete old " -NoNewline
	Write-Host "M" -NoNewline -ForegroundColor Yellow
	Write-Host "iners" -NoNewline
	if ($global:HasConfirm -eq $false -and $global:NeedConfirm -eq $true) {
		Write-Host ", Need " -NoNewline
		Write-Host "Y" -NoNewline -ForegroundColor Yellow
		Write-Host "our confirmation for new pools/bench's" -NoNewline
	}
	Write-Host
	if ($global:API.Running) {
		$global:API.Info = $Summary | Select-Object ($Summary.Columns()) | ConvertTo-Html -Fragment
	}
}

function Get-Confirm {
	if ($global:HasConfirm -eq $false -and $global:NeedConfirm -eq $true) {
		Write-Host "Press " -NoNewline
		Write-Host "Y" -NoNewline -ForegroundColor Yellow
		Write-Host " key - Need Your confirmation for new pools/bench's"
		$start = [Diagnostics.Stopwatch]::new()
		$start.Start()
		do {
			Start-Sleep -Milliseconds ([Config]::SmallTimeout)
			while ([Console]::KeyAvailable -eq $true) {
				[ConsoleKeyInfo] $key = [Console]::ReadKey($true)
				if ($key.Key -eq [ConsoleKey]::Y -and $global:HasConfirm -eq $false -and $global:NeedConfirm -eq $true) {
					Write-Host "Thanks ..." -ForegroundColor Green
					Start-Sleep -Milliseconds ([Config]::SmallTimeout * 2)
					$global:HasConfirm = $true
					$global:NeedConfirm = $false
				}
				Remove-Variable key
			}
		} while ($start.Elapsed.TotalSeconds -lt $Config.LoopTimeout -and !$global:HasConfirm)
		Remove-Variable start
	}
	else {
		Start-Sleep $Config.LoopTimeout
	}
}