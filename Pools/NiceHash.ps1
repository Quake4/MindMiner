<#
MindMiner  Copyright (C) 2017-2022  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::UseApiProxy) { return $null }

if ($Config.Wallet.BTC -and $Config.Wallet.NiceHashNew -and $Config.Wallet.BTC -ne $Config.Wallet.NiceHashNew) {
	if (!$Config.Wallet.NiceHash -or $Config.Wallet.NiceHash -ne $Config.Wallet.NiceHashNew) {
		Write-Host "Please change 'NiceHashNew' wallet to 'NiceHash' wallet in 'config.txt' file." -ForegroundColor Yellow
		Start-Sleep -Seconds ($Config.CheckTimeout)
	}
}

if (!$Config.Wallet.BTC -and !$Config.Wallet.NiceHash) { return $null }

$PoolInfo = [PoolInfo]::new()
$PoolInfo.Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreatePoolConfig "Do you want to mine on $($PoolInfo.Name) (>0.1 BTC every day, >0.001 BTC every week)" ([IO.Path]::Combine($PSScriptRoot, $PoolInfo.Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	AverageProfit = "20 min"
	EnabledAlgorithms = $null
	DisabledAlgorithms = $null
	Region = $null
}
if ($global:AskPools -eq $true -or !$Cfg) { return $null }

if ($Config.Wallet.NiceHash) {
	$Wallet = $Config.Wallet.NiceHash
	$Sign = "NiceHash"
	$Fee = 2
} else {
	$Wallet = $Config.Wallet.BTC
	$Sign = "BTC"
	$Fee = 5
}

if (!$Wallet) { return $null }

$PoolInfo.Enabled = $Cfg.Enabled
$PoolInfo.AverageProfit = $Cfg.AverageProfit

if (!$Cfg.Enabled) { return $PoolInfo }
[decimal] $Pool_Variety = if ($Cfg.Variety) { $Cfg.Variety } else { 0.96 }

if ($Config.Wallet.BTC -eq $Config.Wallet.NiceHash) {
	Write-Host "Please remove NiceHash wallet from 'config.txt' since it matches the BTC wallet. NiceHash wallet only for internal NiceHash wallets." -ForegroundColor Yellow
	Start-Sleep -Seconds ($Config.CheckTimeout)
}
<#
try {
	$RequestAlgo = Get-Rest "https://api2.nicehash.com/main/api/v2/mining/algorithms"
}
catch { return $PoolInfo }
#>
try {
	$RequestInfo = Get-Rest "https://api2.nicehash.com/main/api/v2/public/simplemultialgo/info"
}
catch { return $PoolInfo }

try {
	if (![Config]::UseApiProxy -and $Config.ShowBalance) {
		$RequestBalance = Get-Rest "https://api2.nicehash.com/main/api/v2/mining/external/$Wallet/rigs2"
	}
}
catch { }

if (!$RequestInfo) { return $PoolInfo }
$PoolInfo.HasAnswer = $true
$PoolInfo.AnswerTime = [DateTime]::Now

if ($RequestBalance) {
	$PoolInfo.Balance.Add("BTC", [BalanceInfo]::new([decimal]$RequestBalance.externalBalance, [decimal]$RequestBalance.unpaidAmount))
}

[string] $Pool_Region = "usa-east"
$Regions = @("eu-west", "eu-north", "usa-east", "usa-west")
switch ($Config.Region) {
	"$([eRegion]::Europe)" { $Pool_Region = "eu-north" }
	"$([eRegion]::China)" { $Pool_Region = "usa-west" }
	"$([eRegion]::Japan)" { $Pool_Region = "usa-west" }
}
if (![string]::IsNullOrWhiteSpace($Cfg.Region) -and $Regions -contains $Cfg.Region) {
	$Pool_Region = $Cfg.Region.ToLower();
}
$Regions = $Regions | Sort-Object @{ Expression = { if ($_ -eq $Pool_Region) { 1 } elseif ($_ -eq "eu-north" -or $_ -eq "usa-west") { 3 } elseif ($_ -eq "eu-west" -or $_ -eq "usa-east") { 2 } else { 4 } } } |
	Select-Object -First 3
<#
$paying = [Collections.Generic.Dictionary[string, decimal]]::new()

$RequestInfo.miningAlgorithms | Where-Object paying -GT 0 | ForEach-Object {
	$paying.Add($_.algorithm.ToLower(), [decimal]$_.paying)
}
#>
# $RequestAlgo.miningAlgorithms | Where-Object enabled | ForEach-Object {
$RequestInfo.miningAlgorithms | Where-Object paying -GT 0 | ForEach-Object {	
	$alg = $_.algorithm.ToLower()
	$Pool_Algorithm = Get-Algo $alg
	if ($Pool_Algorithm -and $Cfg.DisabledAlgorithms -notcontains $Pool_Algorithm) {
		$Pool_Hosts = $Regions | ForEach-Object { "$alg.auto.nicehash.com" }
		$Pool_Port = 9200
		$Pool_Diff = if ($AllAlgos.Difficulty.$Pool_Algorithm) { "d=$($AllAlgos.Difficulty.$Pool_Algorithm)" } else { [string]::Empty }
		$Pool_Protocol = "stratum+tcp"
		if ($Config.SSL -eq $true) {
			$Pool_Protocol = "stratum+ssl"
			$Pool_Port = 443
		}
		# $Profit = $paying.$alg * (100 - $Fee) / 100 * $Pool_Variety / 100000000
		$Profit = $_.paying * (100 - $Fee) / 100 * $Pool_Variety / 100000000
		if ($Profit -gt 0) {
			$ProfitFast = $Profit
			$Profit = Set-Stat -Filename $PoolInfo.Name -Key $Pool_Algorithm -Value $Profit -Interval $Cfg.AverageProfit

			$PoolInfo.Algorithms.Add([PoolAlgorithmInfo] @{
				Name = $PoolInfo.Name
				Algorithm = $Pool_Algorithm
				Info = $Pool_Region.ToUpper().Replace("-NORTH", "/N").Replace("-EAST", "/E").Replace("-WEST", "/W")
				InfoAsKey = $true
				Profit = if (($Config.Switching -as [eSwitching]) -eq [eSwitching]::Fast) { $ProfitFast } else { $Profit }
				Protocol = $Pool_Protocol
				Hosts = $Pool_Hosts
				Port = $Pool_Port
				PortUnsecure = $_.port
				User = "$(([Config]::WalletPlaceholder -f $Sign)).$([Config]::WorkerNamePlaceholder)"
				Password = if (![string]::IsNullOrWhiteSpace($Pool_Diff)) { $Pool_Diff } else { $Config.Password }
				Priority = if ($AllAlgos.EnabledAlgorithms -contains $Pool_Algorithm -or $Cfg.EnabledAlgorithms -contains $Pool_Algorithm) { [Priority]::High } else { [Priority]::Normal }
			})
		}
	}
}

Remove-Stat -Filename $PoolInfo.Name -Interval $Cfg.AverageProfit

$PoolInfo