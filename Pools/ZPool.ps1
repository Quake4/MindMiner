<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::UseApiProxy) { return $null }
if (!$Config.Wallet.BTC) { return $null }

$PoolInfo = [PoolInfo]::new()
$PoolInfo.Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateConfig "Do you want to mine on $($PoolInfo.Name) (>0.01 BTC every 24H, >0.0025 BTC ~ weekly)" ([IO.Path]::Combine($PSScriptRoot, $PoolInfo.Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	AverageProfit = "45 min"
	EnabledAlgorithms = $null
	DisabledAlgorithms = $null
}
if ($global:AskPools -eq $true -or !$Cfg) { return $null }

$Wallet = $Config.Wallet.BTC
$Sign = "BTC"

$PoolInfo.Enabled = $Cfg.Enabled
$PoolInfo.AverageProfit = $Cfg.AverageProfit

if (!$Cfg.Enabled) { return $PoolInfo }

[decimal] $Pool_Variety = 0.80
# already accounting Aux's
$AuxCoins = @("UIS", "MBL")

try {
	$RequestStatus = Get-UrlAsJson "https://www.zpool.ca/api/status"
}
catch { return $PoolInfo }

try {
	$RequestCurrency = Get-UrlAsJson "https://www.zpool.ca/api/currencies"
}
catch { return $PoolInfo }

try {
	if ($Config.ShowBalance) {
		$RequestBalance = Get-UrlAsJson "https://www.zpool.ca/api/wallet?address=$Wallet"
	}
}
catch { }

if (!$RequestStatus -or !$RequestCurrency) { return $PoolInfo }
$PoolInfo.HasAnswer = $true
$PoolInfo.AnswerTime = [DateTime]::Now

if ($RequestBalance) {
	$PoolInfo.Balance.Add($Sign, [BalanceInfo]::new([decimal]($RequestBalance.balance), [decimal]($RequestBalance.unsold)))
}

$Currency = $RequestCurrency | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
	[PSCustomObject]@{
		Coin = if (!$RequestCurrency.$_.symbol) { $_ } else { $RequestCurrency.$_.symbol }
		Algo = $RequestCurrency.$_.algo
		Profit = [decimal]$RequestCurrency.$_.estimate / 1000
		Enabled = $RequestCurrency.$_.hashrate -gt 0
	}
}

$Pool_Region = "na"
switch ($Config.Region) {
	"$([eRegion]::Europe)" { $Pool_Region = "eu" }
}

$RequestStatus | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
	$Pool_Algorithm = Get-Algo($RequestStatus.$_.name)
	if ($Pool_Algorithm -and (!$Cfg.EnabledAlgorithms -or $Cfg.EnabledAlgorithms -contains $Pool_Algorithm) -and $Cfg.DisabledAlgorithms -notcontains $Pool_Algorithm -and
		$RequestStatus.$_.actual_last24h -ne $RequestStatus.$_.estimate_last24h -and [decimal]$RequestStatus.$_.actual_last24h -gt 0 -and [decimal]$RequestStatus.$_.estimate_current -gt 0) {
		$Pool_Host = "$($RequestStatus.$_.name).$Pool_Region.mine.zpool.ca"
		$Pool_Port = $RequestStatus.$_.port
		$Pool_Diff = if ($AllAlgos.Difficulty.$Pool_Algorithm) { "d=$($AllAlgos.Difficulty.$Pool_Algorithm)" } else { [string]::Empty }
		$Divisor = 1000000 * $RequestStatus.$_.mbtc_mh_factor

		# convert to one dimension and decimal
		$Algo = $RequestStatus.$_
		$Algo.actual_last24h = [decimal]$Algo.actual_last24h / 1000
		$Algo.estimate_last24h = [decimal]$Algo.estimate_last24h
		$Algo.estimate_current = [decimal]$Algo.estimate_current
		# fix very high or low daily changes
		if ($Algo.estimate_last24h -gt $Algo.actual_last24h * [Config]::MaxTrustGrow) { $Algo.estimate_last24h = $Algo.actual_last24h * [Config]::MaxTrustGrow }
		if ($Algo.actual_last24h -gt $Algo.estimate_last24h * [Config]::MaxTrustGrow) { $Algo.actual_last24h = $Algo.estimate_last24h * [Config]::MaxTrustGrow }
		if ($Algo.estimate_last24h -gt $Algo.estimate_current * [Config]::MaxTrustGrow) { $Algo.estimate_last24h = $Algo.estimate_current * [Config]::MaxTrustGrow }

		# find more profit coin in algo
		$MaxCoin = $null;
		$CurrencyFiltered = $Currency | Where-Object { $_.Algo -eq $Algo.name -and $_.Profit -gt 0 }
		$CurrencyFiltered | ForEach-Object {
			if ($_.Profit -gt $Algo.estimate_last24h * [Config]::MaxTrustGrow) { $_.Profit = $Algo.estimate_last24h * [Config]::MaxTrustGrow }
			if ($MaxCoin -eq $null -or $_.Profit -gt $MaxCoin.Profit) { $MaxCoin = $_ }
		}
		
		if ($MaxCoin -and $MaxCoin.Profit -gt 0) {
			[decimal] $Profit = $MaxCoin.Profit
			if ($Algo.estimate_current -gt $Profit) { $Algo.estimate_current = $Profit }

			[decimal] $CurrencyAverage = ($CurrencyFiltered | Where-Object { !$AuxCoins.Contains($_.Coin) -and $_.Enabled } | Measure-Object -Property Profit -Average).Average
			# $CurrencyAverage += ($CurrencyFiltered | Where-Object { $AuxCoins.Contains($_.Coin) } | Measure-Object -Property Profit -Sum).Sum

			$Profit = ([Math]::Min($Algo.estimate_current, $Algo.actual_last24h) + ($Algo.estimate_current * $CurrencyAverage) / 2) / 2
			$Profit = $Profit * (1 - [decimal]$Algo.fees / 100) * $Pool_Variety / $Divisor
			$ProfitFast = $Profit
			$Profit = Set-Stat -Filename $PoolInfo.Name -Key $Pool_Algorithm -Value $Profit -Interval $Cfg.AverageProfit

			if ([int]$RequestStatus.$_.workers -ge $Config.MinimumMiners) {
				$PoolInfo.Algorithms.Add([PoolAlgorithmInfo] @{
					Name = $PoolInfo.Name
					Algorithm = $Pool_Algorithm
					Profit = if (($Config.Switching -as [eSwitching]) -eq [eSwitching]::Fast) { $ProfitFast } else { $Profit }
					Info = $MaxCoin.Coin
					Protocol = "stratum+tcp"
					Host = $Pool_Host
					Port = $Pool_Port
					PortUnsecure = $Pool_Port
					User = ([Config]::WalletPlaceholder -f $Sign)
					Password = Get-Join "," @("c=$Sign", $Pool_Diff, [Config]::WorkerNamePlaceholder)
				})
			}
		}
	}
}

Remove-Stat -Filename $PoolInfo.Name -Interval $Cfg.AverageProfit

$PoolInfo