<#
MindMiner  Copyright (C) 2017-2019  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::UseApiProxy) { return $null }
if (!$Config.Wallet) { return $null }

$PoolInfo = [PoolInfo]::new()
$PoolInfo.Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreatePoolConfig "Do you want to mine on $($PoolInfo.Name) (>0.01 BTC every 24H, >0.0025 BTC ~ weekly)" ([IO.Path]::Combine($PSScriptRoot, $PoolInfo.Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	AverageProfit = "45 min"
	EnabledAlgorithms = $null
	DisabledAlgorithms = $null
	SpecifiedCoins = $null
}
if ($global:AskPools -eq $true -or !$Cfg) { return $null }

$Sign = "BTC"
$wallets = $Config.Wallet | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object { "$_" -notmatch "nicehash" }
if ($wallets -is [string]) {
	$Sign = "$wallets"
}
$Wallet = $Config.Wallet.$Sign
if ($Config.Wallet."$($Cfg.Wallet)") {
	$Wallet = $Config.Wallet."$($Cfg.Wallet)"
	$Sign = $Cfg.Wallet
}
elseif (![string]::IsNullOrWhiteSpace($Cfg.Wallet)) {
	Write-Host "Wallet '$($Cfg.Wallet)' specified in file '$($PoolInfo.Name).config.txt' isn't found. $($PoolInfo.Name) disabled." -ForegroundColor Red
	return $null
}
if (!$Wallet) { return $null }

$PoolInfo.Enabled = $Cfg.Enabled
$PoolInfo.AverageProfit = $Cfg.AverageProfit

if (!$Cfg.Enabled) { return $PoolInfo }

[decimal] $Pool_Variety = if ($Cfg.Variety) { $Cfg.Variety } else { 0.85 }
# already accounting Aux's
$AuxCoins = @("UIS")

if ($null -eq $Cfg.SpecifiedCoins) {
	$Cfg.SpecifiedCoins = @{ "Allium" = "TUX"; "Bitcore" = "BTX"; "Equihash192" = "ZER"; "Hex" = "XDNA"; "Hmq1725" = "PLUS1"; "Lyra2v3" = "VTC"; "Phi2" = "GEX"; "Skein" = "DGB"; "Skunk" = "MBGL"; "Tribus" = "D"; "X16r" = "XGCS"; "X21s" = "PGN"; "X25x" = "SIN"; "Xevan" = "BSD"; "Yescrypt" = "XMY"; "Yespower" = "CRP" }
}

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
		Profit = [decimal]$RequestCurrency.$_.estimate
		Hashrate = $RequestCurrency.$_.hashrate 
		BTC24h = $RequestCurrency.$_."24h_btc"
	}
} | Group-Object -Property Algo -AsHashTable

$Pool_Region = "na"
$Regions = @("na", "eu", "sea", "jp")
switch ($Config.Region) {
	"$([eRegion]::Europe)" { $Pool_Region = "eu" }
	"$([eRegion]::China)" { $Pool_Region = "sea" }
	"$([eRegion]::Japan)" { $Pool_Region = "jp" }
}

$RequestStatus | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
	$Algo = $RequestStatus.$_
	$Pool_Algorithm = Get-Algo($Algo.name)
	if ($Pool_Algorithm -and $Currency."$($Algo.name)" -and $Cfg.DisabledAlgorithms -notcontains $Pool_Algorithm -and
		$Algo.actual_last24h -ne $Algo.estimate_last24h -and [decimal]$Algo.estimate_current -gt 0 -and [decimal]$Algo.hashrate_last24h -gt 0) {
		$Pool_Hosts = $Regions | Sort-Object @{ Expression = { if ($_.StartsWith($Pool_Region, [StringComparison]::InvariantCultureIgnoreCase)) { 1 } 
			elseif ($_.StartsWith("jp", [StringComparison]::InvariantCultureIgnoreCase)) { 3 } else { 2 } } } |
			Select-Object -First 3 | ForEach-Object { "$($Algo.name).$_.mine.zpool.ca" }
		$Pool_Port = $Algo.port
		$Pool_Diff = if ($AllAlgos.Difficulty.$Pool_Algorithm) { "d=$($AllAlgos.Difficulty.$Pool_Algorithm)" } else { [string]::Empty }
		$Divisor = 1000000 * $Algo.mbtc_mh_factor
		$CurrencyFiltered = $Currency."$($Algo.name)"

		# recalc
		$Algo.actual_last24h = [decimal][Math]::Min([decimal]$Algo.actual_last24h / 1000, ($CurrencyFiltered | Measure-Object "BTC24h" -Sum)[0].Sum * $Divisor / [decimal]$Algo.hashrate_last24h)
		$Algo.estimate_current = [decimal][Math]::Min([decimal]$Algo.estimate_current, ($CurrencyFiltered | Measure-Object "Profit" -Maximum)[0].Maximum)
		# fix very high or low daily changes
		if ($Algo.estimate_current -gt $Algo.actual_last24h * $Config.MaximumAllowedGrowth) {
			$Algo.estimate_current = if ($Algo.actual_last24h -gt 0) { $Algo.actual_last24h * $Config.MaximumAllowedGrowth } else { $Algo.estimate_current * $Pool_Variety }
		}

		# find more profit coin in algo
		$MaxCoin = $null;
		$CurrencyFiltered | ForEach-Object {
			if ($_.Profit -gt $Algo.estimate_current * $Config.MaximumAllowedGrowth) { $_.Profit = $Algo.estimate_current * $Config.MaximumAllowedGrowth }
			if ($MaxCoin -eq $null -or $_.Profit -gt $MaxCoin.Profit) { $MaxCoin = $_ }

			if ($Cfg.SpecifiedCoins.$Pool_Algorithm -eq $_.Coin -or $Cfg.SpecifiedCoins.$Pool_Algorithm -contains $_.Coin) {
				$coins = $Cfg.SpecifiedCoins.$Pool_Algorithm | Where-Object { !$_.Contains("only") -and !$_.Contains("solo") -and !$_.Contains("party") }
				$coins = $CurrencyFiltered | Where-Object { $_.Coin -eq $coins -or $coins -contains $_.Coin } | Select-Object -ExpandProperty Coin
				if ($coins) {
					[decimal] $Profit = ([Math]::Min($_.Profit, $Algo.actual_last24h) + $_.Profit) / 2
					$Profit = $Profit * (1 - [decimal]$Algo.fees / 100) * $Pool_Variety / $Divisor
					$ProfitFast = $Profit
					if ($Profit -gt 0) {
						$Profit = Set-Stat -Filename $PoolInfo.Name -Key "$Pool_Algorithm`_$($_.Coin)" -Value $Profit -Interval $Cfg.AverageProfit
					}

					if ([int]$Algo.workers -ge $Config.MinimumMiners -or $global:HasConfirm) {
						$PoolInfo.Algorithms.Add([PoolAlgorithmInfo] @{
							Name = "$($PoolInfo.Name)-$($Pool_Region.ToUpper())"
							Algorithm = $Pool_Algorithm
							Profit = if (($Config.Switching -as [eSwitching]) -eq [eSwitching]::Fast) { $ProfitFast } else { $Profit }
							Info = (Get-Join "/" $coins) + "*"
							InfoAsKey = $true
							Protocol = "stratum+tcp"
							Hosts = $Pool_Hosts
							Port = $Pool_Port
							PortUnsecure = $Pool_Port
							User = ([Config]::WalletPlaceholder -f $Sign)
							Password = Get-Join "," @("c=$Sign", "zap=$(Get-Join "/" $coins)", $Pool_Diff, [Config]::WorkerNamePlaceholder)
							Priority = if ($AllAlgos.EnabledAlgorithms -contains $Pool_Algorithm -or $Cfg.EnabledAlgorithms -contains $Pool_Algorithm) { [Priority]::High } else { [Priority]::Normal }
						})
					}
				}
			}
		}
		
		if ($MaxCoin -and $MaxCoin.Profit -gt 0 -and $Cfg.SpecifiedCoins.$Pool_Algorithm -notcontains "only") {
			[decimal] $CurrencyAverage = $Algo.estimate_current;
			try {
				$onlyAux = $AuxCoins.Contains($CurrencyFiltered.Coin)
				$CurrencyAverage = [decimal]($CurrencyFiltered | Select-Object @{ Label = "Profit"; Expression= { $_.Profit * $_.Hashrate }} |
					Measure-Object -Property Profit -Sum).Sum / ($CurrencyFiltered |
					Where-Object { $onlyAux -or !$AuxCoins.Contains($_.Coin) } | Measure-Object -Property Hashrate -Sum).Sum
			}
			catch { }

			[decimal] $avecur = ($Algo.estimate_current + $CurrencyAverage) / 2
			[decimal] $Profit = ($avecur + [Math]::Min($avecur, $Algo.actual_last24h)) / 2
			$Profit = $Profit * (1 - [decimal]$Algo.fees / 100) * $Pool_Variety / $Divisor
			$ProfitFast = $Profit
			if ($Profit -gt 0) {
				$Profit = Set-Stat -Filename $PoolInfo.Name -Key $Pool_Algorithm -Value $Profit -Interval $Cfg.AverageProfit
			}

			if ([int]$Algo.workers -ge $Config.MinimumMiners -or $global:HasConfirm) {
				$PoolInfo.Algorithms.Add([PoolAlgorithmInfo] @{
					Name = "$($PoolInfo.Name)-$($Pool_Region.ToUpper())"
					Algorithm = $Pool_Algorithm
					Profit = if (($Config.Switching -as [eSwitching]) -eq [eSwitching]::Fast) { $ProfitFast } else { $Profit }
					Info = $MaxCoin.Coin
					Protocol = "stratum+tcp"
					Hosts = $Pool_Hosts
					Port = $Pool_Port
					PortUnsecure = $Pool_Port
					User = ([Config]::WalletPlaceholder -f $Sign)
					Password = Get-Join "," @("c=$Sign", $Pool_Diff, [Config]::WorkerNamePlaceholder)
					Priority = if ($AllAlgos.EnabledAlgorithms -contains $Pool_Algorithm -or $Cfg.EnabledAlgorithms -contains $Pool_Algorithm) { [Priority]::High } else { [Priority]::Normal }
				})
			}
		}
	}
}

Remove-Stat -Filename $PoolInfo.Name -Interval $Cfg.AverageProfit

$PoolInfo