<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Include.ps1

if ([Config]::UseApiProxy) { return $null }

$PoolInfo = [PoolInfo]::new()
$PoolInfo.Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateConfig "Do you want to mine on $($PoolInfo.Name) (>0.005 BTC every 5H, >0.0005 BTC sunday)" ([IO.Path]::Combine($PSScriptRoot, $PoolInfo.Name + [BaseConfig]::Filename)) @{
	Enabled = $false
	AverageProfit = "1 hour 30 min"
	EnabledAlgorithms = $null
	DisabledAlgorithms = $null
	SpecifiedCoins = $null
}
if (!$Cfg) { return $null }
if (!$Config.Wallet.BTC -and !$Config.Wallet.LTC) { return $null }

$Wallet = if ($Config.Wallet.LTC) { $Config.Wallet.LTC } else { $Config.Wallet.BTC }
$Sign = if ($Config.Wallet.LTC) { "LTC" } else { "BTC" }

$PoolInfo.Enabled = $Cfg.Enabled
$PoolInfo.AverageProfit = $Cfg.AverageProfit

if (!$Cfg.Enabled) { return $PoolInfo }

[decimal] $Pool_Variety = 0.80
# already accounting Aux's
$AuxCoins = @("UIS", "MBL")

if ($Cfg.SpecifiedCoins -eq $null) {
	$Cfg.SpecifiedCoins = @{ "Lyra2z" = "GIN"; "Phi" = "FLM"; "Skein" = "DGB"; "Tribus" = "DNR"; "X16r" = "RVN"; "X16s" = "PGN"; "X17" = "XVG"; "Yescryptr16" = "CRP" }
}

try {
	$RequestStatus = Get-UrlAsJson "http://blockmasters.co/api/status"
}
catch { return $PoolInfo }

try {
	$RequestCurrency = Get-UrlAsJson "http://blockmasters.co/api/currencies"
}
catch { return $PoolInfo }

try {
	if ($Config.ShowBalance) {
		$RequestBalance = Get-UrlAsJson "http://blockmasters.co/api/walletEx?address=$Wallet"
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

$RequestStatus | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
	$Pool_Algorithm = Get-Algo($RequestStatus.$_.name)
	if ($Pool_Algorithm -and (!$Cfg.EnabledAlgorithms -or $Cfg.EnabledAlgorithms -contains $Pool_Algorithm) -and $Cfg.DisabledAlgorithms -notcontains $Pool_Algorithm -and
		$RequestStatus.$_.actual_last24h -ne $RequestStatus.$_.estimate_last24h -and [decimal]$RequestStatus.$_.actual_last24h -gt 0 -and [decimal]$RequestStatus.$_.estimate_current -gt 0 -and
		[int]$RequestStatus.$_.workers -ge $Config.MinimumMiners) {
		$Pool_Host = "blockmasters.co"
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

			if ($Cfg.SpecifiedCoins.$Pool_Algorithm -eq $_.Coin -or $Cfg.SpecifiedCoins.$Pool_Algorithm -contains $_.Coin) {
				[decimal] $Profit = $_.Profit * [Config]::CurrentOf24h + ([Math]::Min($Algo.estimate_last24h, $Algo.actual_last24h) + $Algo.actual_last24h) / 2 * (1 - [Config]::CurrentOf24h)
				$Profit = $Profit * (1 - [decimal]$Algo.fees / 100) * $Pool_Variety / $Divisor
				$Profit = Set-Stat -Filename ($PoolInfo.Name) -Key "$Pool_Algorithm`_$($_.Coin)" -Value $Profit -Interval $Cfg.AverageProfit

				$PoolInfo.Algorithms.Add([PoolAlgorithmInfo] @{
					Name = $PoolInfo.Name
					Algorithm = $Pool_Algorithm
					Profit = $Profit
					Info = $_.Coin + "*"
					InfoAsKey = $true
					Protocol = "stratum+tcp"
					Host = $Pool_Host
					Port = $Pool_Port
					PortUnsecure = $Pool_Port
					User = ([Config]::WalletPlaceholder -f $Sign)
					Password = Get-Join "," @("c=$Sign", "mc=$($_.Coin)", $Pool_Diff, [Config]::WorkerNamePlaceholder)
				})
			}
		}

		if ($MaxCoin -and $MaxCoin.Profit -gt 0 -and $Cfg.SpecifiedCoins.$Pool_Algorithm -notcontains "only") {
			[decimal] $Profit = $MaxCoin.Profit
			if ($Algo.estimate_current -gt $Profit * [Config]::MaxTrustGrow) { $Algo.estimate_current = $Profit * [Config]::MaxTrustGrow }

			[decimal] $CurrencyAverage = ($CurrencyFiltered | Where-Object { !$AuxCoins.Contains($_.Coin) -and $_.Enabled } | Measure-Object -Property Profit -Average).Average
			# $CurrencyAverage += ($CurrencyFiltered | Where-Object { $AuxCoins.Contains($_.Coin) } | Measure-Object -Property Profit -Sum).Sum

			$Profit = ($Algo.estimate_current + $CurrencyAverage) / 2 * [Config]::CurrentOf24h + ([Math]::Min($Algo.estimate_last24h, $Algo.actual_last24h) + $Algo.actual_last24h) / 2 * (1 - [Config]::CurrentOf24h)
			$Profit = $Profit * (1 - [decimal]$Algo.fees / 100) * $Pool_Variety / $Divisor
			$Profit = Set-Stat -Filename ($PoolInfo.Name) -Key $Pool_Algorithm -Value $Profit -Interval $Cfg.AverageProfit

			$PoolInfo.Algorithms.Add([PoolAlgorithmInfo] @{
				Name = $PoolInfo.Name
				Algorithm = $Pool_Algorithm
				Profit = $Profit
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

$PoolInfo