<#
MindMiner  Copyright (C) 2017-2022  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::UseApiProxy) { return $null }
if (!$Config.Wallet) { return $null }

$PoolInfo = [PoolInfo]::new()

$PoolInfo.Name = (Get-Culture).TextInfo.ToTitleCase((Get-Item $script:MyInvocation.MyCommand.Path).BaseName)

$Cfg = ReadOrCreatePoolConfig "Do you want to mine on $($PoolInfo.Name) (>0.0015 BTC every day)" ([IO.Path]::Combine($PSScriptRoot, $PoolInfo.Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	AverageProfit = "45 min"
	EnabledAlgorithms = $null
	DisabledAlgorithms = $null
	SpecifiedCoins = $null
	UseGlobal = $false
}
if ($global:AskPools -eq $true -or !$Cfg) { return $null }

$Sign = "BTC"
$wallets = $Config.Wallet | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name |
	Where-Object { ![string]::IsNullOrWhiteSpace($Config.Wallet.$_) } |	Where-Object { "$_" -notmatch "nicehash" }
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

[decimal] $Pool_Variety = if ($Cfg.Variety) { $Cfg.Variety } else { 0.90 }
# already accounting Aux's
$AuxCoins = @("UIS")

if ($null -eq $Cfg.SpecifiedCoins) {
	$Cfg.SpecifiedCoins = @{ "Allium" = "TUX"; "Bitcore" = "BTX"; "Equihash192" = "ZER"; "Hex" = "XDNA"; "Hmq1725" = "PLUS1"; "Lyra2v3" = "VTC"; "Phi2" = "GEX"; "Skein" = "DGB"; "Skunk" = "MBGL"; "Tribus" = "D"; "X16r" = "XGCS"; "X21s" = "PGN"; "X25x" = "SIN"; "Xevan" = "BSD"; "Yescrypt" = "XMY"; "Yespower" = "CRP" }
}

try {
	$RequestStatus = Get-Rest "https://www.zpool.ca/api/status"
}
catch { return $PoolInfo }

try {
	$RequestCurrency = Get-Rest "https://www.zpool.ca/api/currencies"
}
catch { return $PoolInfo }

try {
	if (![Config]::UseApiProxy -and $Config.ShowBalance) {
		$RequestBalance = Get-Rest "https://www.zpool.ca/api/wallet?address=$Wallet"
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
	if ($RequestCurrency.$_.algo -and !($RequestCurrency.$_.conversion_disabled -eq "1")) {
		[PSCustomObject]@{
			Coin = if (!$RequestCurrency.$_.symbol) { if ($_.StartsWith("HashTap")) { "HashTap" } else { $_ } } else { $RequestCurrency.$_.symbol }
			Algo = $RequestCurrency.$_.algo
			Profit = [decimal]$RequestCurrency.$_.estimate
			Hashrate = $RequestCurrency.$_.hashrate 
			BTC24h = $RequestCurrency.$_."24h_btc"
		}
	}
} | Group-Object -Property Algo -AsHashTable

if (!$Cfg.UseGlobal) {
	$Pool_Region = "na"
	$Regions = @("na", "eu", "sea", "jp")
	switch ($Config.Region) {
		"$([eRegion]::Europe)" { $Pool_Region = "eu" }
		"$([eRegion]::China)" { $Pool_Region = "sea" }
		"$([eRegion]::Japan)" { $Pool_Region = "jp" }
	}
	$Regions = $Regions | Sort-Object @{ Expression = { if ($_ -eq $Pool_Region) { 1 } elseif ($_ -eq "na" -or $_ -eq "eu") { 2 } elseif ($_ -eq "jp") { 4 } else { 3 } } } |
		Select-Object -First 3
}

$RequestStatus | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
	$Algo = $RequestStatus.$_
	$Pool_Algorithm = Get-Algo $Algo.name
	if ($Pool_Algorithm -and $Currency."$($Algo.name)" -and $Cfg.DisabledAlgorithms -notcontains $Pool_Algorithm -and
		$Algo.actual_last24h -ne $Algo.estimate_last24h -and [decimal]$Algo.estimate_current -gt 0 -and [decimal]$Algo.hashrate_last24h -gt 0) {
		$Pool_Hosts = $(if ($Cfg.UseGlobal) { "$($Algo.name).mine.zpool.ca" } else { $Regions | ForEach-Object { "$($Algo.name).$_.mine.zpool.ca" } } )
		$Pool_Protocol = "stratum+tcp"
		$Pool_Port = $Algo.port
		$Pool_PortUsecure = $Algo.port
		if ($Config.SSL -eq $true) {
			$Pool_Protocol = "stratum+ssl"
			$Pool_Port = $Algo.ssl_port
		}
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

			if ($Cfg.SpecifiedCoins.$Pool_Algorithm -eq $_.Coin -or $Cfg.SpecifiedCoins.$Pool_Algorithm -contains $_.Coin -or $Config.Wallet."$($_.Coin)") {
				$sgn = $Sign
				$coins = if ($Cfg.SpecifiedCoins.$Pool_Algorithm) { $Cfg.SpecifiedCoins.$Pool_Algorithm | Where-Object { !$_.Contains("only") -and !$_.Contains("solo") -and !$_.Contains("party") } }
					else { $sgn = $_.Coin; @($_.Coin) }
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
							Name = $(if ($Cfg.UseGlobal) { $PoolInfo.Name } else { "$($PoolInfo.Name)-$($Pool_Region.ToUpper())" } ) 
							Algorithm = $Pool_Algorithm
							Profit = if (($Config.Switching -as [eSwitching]) -eq [eSwitching]::Fast) { $ProfitFast } else { $Profit }
							Info = (Get-Join "/" $coins) + "*"
							InfoAsKey = $true
							Protocol = $Pool_Protocol
							Hosts = $Pool_Hosts
							Port = $Pool_Port
							PortUnsecure = $Pool_PortUsecure
							User = ([Config]::WalletPlaceholder -f $sgn)
							Password = Get-Join "," @("c=$sgn", "zap=$(Get-Join "/" $coins)", $Pool_Diff, [Config]::WorkerNamePlaceholder)
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
					Name = $(if ($Cfg.UseGlobal) { $PoolInfo.Name } else { "$($PoolInfo.Name)-$($Pool_Region.ToUpper())" } ) 
					Algorithm = $Pool_Algorithm
					Profit = if (($Config.Switching -as [eSwitching]) -eq [eSwitching]::Fast) { $ProfitFast } else { $Profit }
					Info = $MaxCoin.Coin
					Protocol = $Pool_Protocol
					Hosts = $Pool_Hosts
					Port = $Pool_Port
					PortUnsecure = $Pool_PortUsecure
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