<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Config.ps1

function Get-Config {
	[Config] $cfg = $null
	if ([Config]::Exists() -eq $false) {
		Write-Host "Missing configuration file 'config.txt'. Create. Please, enter BTC wallet address now and change other parameters later." -ForegroundColor red
		do {
			$btcwal = Read-Host "Enter Your BTC wallet"
		} while ([string]::IsNullOrWhiteSpace($btcwal))
		$login = Read-Host "Enter Your Username for pools with registration (or press Enter for empty)"
		Write-Host "Use CPU for mining (Yes/No)?: " -NoNewline
		[ConsoleKeyInfo] $y = [Console]::ReadKey()
		$cfg = [Config]::new()
		$cfg.Wallet.BTC = $btcwal
		$cfg.Login = $login
		if ($y.Key -ne [ConsoleKey]::Y) {
			$cfg.AllowedTypes = $cfg.AllowedTypes | Where-Object { $_ -ne "CPU" }
		}
		$cfg.Save()
		Remove-Variable login, btcwal
	}
	else {
		$cfg = [Config]::Read()
		$val = $cfg.Validate()
		if (![string]::IsNullOrWhiteSpace($val)) {
			Write-Host ("Configuration:" + [Environment]::NewLine + $cfg)
			Write-Host ("Error in configuration file 'config.txt'. Please fill needed parameter(s): " + $val) -ForegroundColor red
			$cfg = $null
		}
		Remove-Variable val
	}
	if ($cfg) {
		# remove from static constructor of [Config] to remove deadlock
		[Config]::CPUFeatures = Get-CPUFeatures ([Config]::BinLocation)
		[Config]::AMDPlatformId = Get-AMDPlatformId ([Config]::BinLocation)
		[Config]::RateTimeout = [HumanInterval]::Parse("1 hour")
		# filter has by allowed types
		[Config]::ActiveTypes = [Config]::ActiveTypes | Where-Object {
			$cfg.AllowedTypes -contains $_
		}
		# set default value if empty
		if (!$cfg.Currencies -or $cfg.Currencies.Count -eq 0) {
			$hash = [Collections.Generic.Dictionary[string, object]]::new()
			$hash.Add("BTC", 8)
			$hash.Add("USD", 2)
			$cfg.Currencies = $hash
		}
	}
	$cfg
}