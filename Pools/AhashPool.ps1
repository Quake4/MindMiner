<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::UseApiProxy) { return $null }
if (!$Config.Wallet.BTC) { return $null }

$PoolInfo = [PoolInfo]::new()
$PoolInfo.Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreatePoolConfig "Do you want to mine on $($PoolInfo.Name) (>0.003 BTC every 24H)" ([IO.Path]::Combine($PSScriptRoot, $PoolInfo.Name + [BaseConfig]::Filename)) @{
	Enabled = $false
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

[decimal] $Pool_Variety = if ($Cfg.Variety) { $Cfg.Variety } else { 0.85 }
# already accounting Aux's
$AuxCoins = @("UIS")

try {
	$RequestStatus = Get-UrlAsJson "https://www.ahashpool.com/api/status"
}
catch { return $PoolInfo }

try {
	$RequestCurrency = Get-UrlAsJson "https://www.ahashpool.com/api/currencies/"
}
catch { return $PoolInfo }

try {
	if ($Config.ShowBalance) {
		$RequestBalance = Get-UrlAsJson "https://www.ahashpool.com/api/wallet?address=$Wallet"
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
		Hashrate = $RequestCurrency.$_.hashrate 
		BTC24h = $RequestCurrency.$_."24h_btc"
	}
} | Group-Object -Property Algo -AsHashTable

$RequestStatus | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
	$Algo = $RequestStatus.$_
	$Pool_Algorithm = Get-Algo($Algo.name)
	if ($Pool_Algorithm -and $Currency."$($Algo.name)" -and (!$Cfg.EnabledAlgorithms -or $Cfg.EnabledAlgorithms -contains $Pool_Algorithm) -and $Cfg.DisabledAlgorithms -notcontains $Pool_Algorithm -and
		$Algo.actual_last24h -ne $Algo.estimate_last24h -and [decimal]$Algo.estimate_current -gt 0 -and [decimal]$Algo.hashrate_last24h -gt 0) {
		$Pool_Host = $Algo.name + ".mine.ahashpool.com"
		$Pool_Port = $Algo.port
		$Pool_Diff = if ($AllAlgos.Difficulty.$Pool_Algorithm) { "d=$($AllAlgos.Difficulty.$Pool_Algorithm)" } else { [string]::Empty }
		$Divisor = 1000000 * $Algo.mbtc_mh_factor

		# convert to one dimension and decimal
		$Algo.actual_last24h = [decimal]$Algo.actual_last24h / 1000
		$Algo.estimate_current = [decimal]$Algo.estimate_current
		# recalc 24h actual
		$Algo.actual_last24h = [Math]::Min($Algo.actual_last24h,
			($Currency."$($Algo.name)" | Measure-Object "BTC24h" -Sum)[0].Sum * $Divisor / [decimal]$Algo.hashrate_last24h)
		# fix very high or low daily changes
		if ($Algo.estimate_current -gt $Algo.actual_last24h * $Config.MaximumAllowedGrowth) { $Algo.estimate_current = $Algo.actual_last24h * $Config.MaximumAllowedGrowth }
		if ($Algo.actual_last24h -gt $Algo.estimate_current * $Config.MaximumAllowedGrowth) { $Algo.actual_last24h = $Algo.estimate_current * $Config.MaximumAllowedGrowth }

		# find more profit coin in algo
		$MaxCoin = $null;
		$CurrencyFiltered = $Currency."$($Algo.name)" | Where-Object { $_.Profit -gt 0 }
		$CurrencyFiltered | ForEach-Object {
			if ($_.Profit -gt $Algo.estimate_current * $Config.MaximumAllowedGrowth) { $_.Profit = $Algo.estimate_current * $Config.MaximumAllowedGrowth }
			if ($MaxCoin -eq $null -or $_.Profit -gt $MaxCoin.Profit) { $MaxCoin = $_ }
		}

		if ($MaxCoin -and $MaxCoin.Profit -gt 0) {
			if ($Algo.estimate_current -gt $MaxCoin.Profit) { $Algo.estimate_current = $MaxCoin.Profit }

			[decimal] $CurrencyAverage = $Algo.estimate_current * 0.5;
			try {
				$onlyAux = $AuxCoins.Contains($CurrencyFiltered.Coin)
				$CurrencyAverage = [decimal]($CurrencyFiltered | Select-Object @{ Label = "Profit"; Expression= { $_.Profit * $_.Hashrate }} |
					Measure-Object -Property Profit -Sum).Sum / ($CurrencyFiltered |
					Where-Object { $onlyAux -or !$AuxCoins.Contains($_.Coin) } | Measure-Object -Property Hashrate -Sum).Sum
			}
			catch { }

			[decimal] $Profit = ([Math]::Min($Algo.estimate_current, $Algo.actual_last24h) + ($Algo.estimate_current + $CurrencyAverage) / 2) / 2
			$Profit = $Profit * (1 - [decimal]$Algo.fees / 100) * $Pool_Variety / $Divisor
			$ProfitFast = $Profit
			if ($Profit -gt 0) {
				$Profit = Set-Stat -Filename $PoolInfo.Name -Key $Pool_Algorithm -Value $Profit -Interval $Cfg.AverageProfit
			}

			if ([int]$Algo.workers -ge $Config.MinimumMiners -or $global:HasConfirm) {
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