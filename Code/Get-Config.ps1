<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Config.ps1

function Get-Config {
	[Config] $cfg = $null
	if ([Config]::Exists() -eq $false) {
		Write-Host "Missing configuration file 'config.txt'. Create. Please, enter BTC wallet address now and change other parameters later." -ForegroundColor Red
		do {
			$btcwal = Read-Host "Enter Your BTC wallet"
		} while ([string]::IsNullOrWhiteSpace($btcwal))
		$cfg = [Config]::new()
		$cfg.Wallet.BTC = $btcwal
		$ltcwal = Read-Host "Enter Your LTC wallet for some pools or press Enter for skip"
		if (![string]::IsNullOrWhiteSpace($ltcwal)) {
			$cfg.Wallet.LTC = $ltcwal
		}
		$nicewal = Read-Host "Enter Your NiceHash internal wallet or press Enter for skip"
		if (![string]::IsNullOrWhiteSpace($nicewal)) {
			$cfg.Wallet.NiceHash = $nicewal
		}
		$login = Read-Host "Enter Your Username for pools with registration (MiningPoolHub) or press Enter for skip"
		$cfg.Login = $login
		if (!(Get-Question "Use CPU for mining")){
			$cfg.AllowedTypes = $cfg.AllowedTypes | Where-Object { $_ -ne "CPU" }
		}
		$cfg.Save()
		$cfg = [Config]::Read()
		Remove-Variable login, btcwal
		$global:HasConfirm = $true
	}
	else {
		$cfg = [Config]::Read()
		$val = $cfg.Validate()
		if (![string]::IsNullOrWhiteSpace($val)) {
			Write-Host ("Configuration:" + [Environment]::NewLine + $cfg)
			Write-Host ("Error in configuration file 'config.txt'. Please fill needed parameter(s): " + $val) -ForegroundColor Red
			$cfg = $null
		}
		Remove-Variable val
	}
	if ($cfg) {
		# remove from static constructor of [Config] to remove deadlock
		[Config]::CPUFeatures = Get-CPUFeatures ([Config]::BinLocation)
		[Config]::RateTimeout = [HumanInterval]::Parse("1 hour")
		# filter has by allowed types
		[Config]::ActiveTypes = [Config]::ActiveTypes | Where-Object { $cfg.AllowedTypes -contains $_ }
		if ([Config]::ActiveTypes -contains [eMinerType]::AMD) {
			[Config]::AMDPlatformId = Get-AMDPlatformId ([Config]::BinLocation)
		}
		# set default value if empty
		if (!$cfg.Currencies -or $cfg.Currencies.Count -eq 0) {
			$hash = [Collections.Generic.List[object]]::new()
			$hash.Add(@("BTC"; 8))
			$hash.Add(@("USD"; 2))
			$cfg.Currencies = $hash
		}
	}
	$cfg
}