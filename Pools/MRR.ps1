<#
MindMiner  Copyright (C) 2018-2019  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

Write-Host "MRRFirst: $($global:MRRFirst)"

if ([Config]::UseApiProxy) { return $null }
if (!$Config.Wallet.BTC) { return $null }

$PoolInfo = [PoolInfo]::new()
$PoolInfo.Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$configfile = $PoolInfo.Name + [BaseConfig]::Filename

$Cfg = ReadOrCreatePoolConfig "Do you want to pass a rig to rent on $($PoolInfo.Name)" ([IO.Path]::Combine($PSScriptRoot, $configfile)) @{
	Enabled = $false
	Key = $null
	Secret = $null
	Region = $null
	# AverageProfit = "45 min"
	EnabledAlgorithms = $null
	DisabledAlgorithms = $null
}
if ($global:AskPools -eq $true -or !$Cfg) { return $null }

$PoolInfo.Enabled = $Cfg.Enabled
# $PoolInfo.AverageProfit = $Cfg.AverageProfit

if (!$Cfg.Enabled) { return $PoolInfo }
if ([string]::IsNullOrWhiteSpace($Cfg.Key) -or [string]::IsNullOrWhiteSpace($Cfg.Secret)) {
	Write-Host "Fill in the `"Key`" and `"Secret`" parameters in the configuration file `"$configfile`" or disable the $($PoolInfo.Name)." -ForegroundColor Yellow
	return $null
}

try {
	$mrr = [MRR]::new($Cfg.Key, $Cfg.Secret);
	$mrr.Debug = $true;
	$result = $mrr.Get("/whoami")
	if (!$result.authed) {
		Write-Host "MRR: Not authorized! Check Key and Secret." -ForegroundColor Yellow
		return $null;
	}
	if ($result.permissions.rigs -ne "yes") {
		Write-Host "MRR: Need grant `"Manage Rigs`"." -ForegroundColor Yellow
		return $null;
	}
	$servers = $mrr.Get("/info/servers")
	if ($Cfg.Region) {
		$server = $servers | Where-Object { $_.region -match $Cfg.Region }
	}
	if (!$server -or $server.Length -gt 1) {
		$servers = $servers | Select-Object -ExpandProperty region
		Write-Host "Set `"Region`" parameter from list ($(Get-Join ", " $servers)) in the configuration file `"$configfile`" or disable the $($PoolInfo.Name)." -ForegroundColor Yellow
		return $null;
	}

	if ($global:MRRFirst) {
		# info as standart pool
		$mrr.Get("/info/algos") | ForEach-Object {
			$Algo = $_
			$Pool_Algorithm = Get-Algo ($Algo.name) $false
			if ($Pool_Algorithm -and (!$Cfg.EnabledAlgorithms -or $Cfg.EnabledAlgorithms -contains $Pool_Algorithm) -and $Cfg.DisabledAlgorithms -notcontains $Pool_Algorithm) {
				Write-Host $Pool_Algorithm
			}
			else {
				Write-Host "Not supported $($_.name)"
			}
		}
	}
	else {
		# check rigs

		# $AllAlgos.Miners -contains $Pool_Algorithm

		$result = $mrr.Get("/rig/mine") | Where-Object { $_.name -match $Config.WorkerName }
		if ($result) {

		}
		else {
			# create rigs on all algos
		}

		# if rented
		$rented = $null
	}
}
catch {
	Write-Host $_
}
finally {
	if ($mrr) {	$mrr.Dispose() }
}

if ($global:MRRFirst) {
	$PoolInfo
}
else {
	$rented
}