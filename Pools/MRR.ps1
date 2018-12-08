<#
MindMiner  Copyright (C) 2017-2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::UseApiProxy) { return $null }
if (!$Config.Wallet.BTC) { return $null }

$PoolInfo = [PoolInfo]::new()
$PoolInfo.Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$configfile = $PoolInfo.Name + [BaseConfig]::Filename

$Cfg = ReadOrCreatePoolConfig "Do you want to pass a rig to rent on $($PoolInfo.Name)" ([IO.Path]::Combine($PSScriptRoot, $configfile)) @{
	Enabled = $false
	Key = $null
	Secret = $null
	# AverageProfit = "45 min"
	# EnabledAlgorithms = $null
	# DisabledAlgorithms = $null
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
	


}
catch {
	Write-Host $_
}
finally {
	if ($mrr) {	$mrr.Dispose() }
}

# $PoolInfo
$null