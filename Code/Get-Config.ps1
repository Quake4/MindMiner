<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Config.ps1

function Get-Config {
	[Config] $cfg = $null
	if ([Config]::Exists() -eq $false) {
		Write-Host "Missing configuration file 'config.txt'. Create. Please, enter wallet address now and change other parameters later." -ForegroundColor Red
		do {
			Write-Host "Need enter one or more of: BTC, LTC, NiceHash or Username." -ForegroundColor Yellow
			$btcwal = Read-Host "Enter Your BTC wallet for some pools or press Enter for skip"
			$ltcwal = Read-Host "Enter Your LTC wallet for some pools or press Enter for skip"
			$nicewal = Read-Host "Enter Your NiceHash internal wallet or press Enter for skip"
			$login = Read-Host "Enter Your Username for pools with registration (MiningPoolHub) or press Enter for skip"
		} while ([string]::IsNullOrWhiteSpace($btcwal) -and [string]::IsNullOrWhiteSpace($ltcwal) -and [string]::IsNullOrWhiteSpace($nicewal) -and [string]::IsNullOrWhiteSpace($login))
		$tmpcfg = [hashtable]@{}
		$tmpcfg.Add("Wallet", [hashtable]@{});
		if (![string]::IsNullOrWhiteSpace($btcwal)) {
			$tmpcfg.Wallet.BTC = $btcwal
		}
		if (![string]::IsNullOrWhiteSpace($ltcwal)) {
			$tmpcfg.Wallet.LTC = $ltcwal
		}
		if (![string]::IsNullOrWhiteSpace($nicewal)) {
			$tmpcfg.Wallet.NiceHash = $nicewal
		}
		$tmpcfg.Login = $login
		if (Get-Question "Do you want to use online monitoring") {
			$apikey = Read-Host "Enter Your Api Key ID or press Enter for get new"
			$count = 5
			while ($count -gt 0 -and [string]::IsNullOrWhiteSpace($apikey)) {
				$count--
				$json = Get-UrlAsJson "http://api.mindminer.online/?type=genapikey"
				if ($json -and $json.apikey) {
					$apikey = $json.apikey
					Write-Host "Api Key ID '$apikey' generated sucessfully. You must use it on http://mindminder.online." -ForegroundColor Yellow
				}
				elseif (!$json -or $json.error) {
					Start-Sleep -Seconds 3
				}
			}
			$tmpcfg.ApiKey = $apikey
		}
		if (!(Get-Question "Use CPU for mining")) {
			$tmpcfg.AllowedTypes = [Config]::new().AllowedTypes | Where-Object { $_ -ne "CPU" }
		}
		do {
			$region = (Read-Host "Enter Your region from list $([Enum]::GetValues([eRegion]) -join ", ")") -as [eRegion]
		} while ($null -eq $region)
		$tmpcfg.Region = "$region"
		[BaseConfig]::Save([Config]::Filename, $tmpcfg)
		Remove-Variable tmpcfg, login, nicewal, btcwal, ltcwal
		$cfg = [Config]::Read()
		$global:AskPools = $true
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

		if ([Config]::ActiveTypes -contains [eMinerType]::AMD -or [Config]::ActiveTypes -contains [eMinerType]::nVidia) {
			$json = Get-OpenCLDeviceDetection ([Config]::BinLocation)
			if ([Config]::ActiveTypes -contains [eMinerType]::AMD) {
				[Config]::AMDPlatformId = Get-AMDPlatformId $json
			}
			if ([Config]::ActiveTypes -contains [eMinerType]::nVidia) {
				[Config]::CudaVersion = Get-CudaVersion $json
			}
			Remove-Variable json
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