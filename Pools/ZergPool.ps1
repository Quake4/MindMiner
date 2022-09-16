<#
MindMiner  Copyright (C) 2017-2022  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::UseApiProxy) { return $null }
if (!$Config.Wallet) { return $null }

$PoolInfo = [PoolInfo]::new()
$PoolInfo.Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreatePoolConfig "Do you want to mine on $($PoolInfo.Name) (>0.0015 BTC every sunday)" ([IO.Path]::Combine($PSScriptRoot, $PoolInfo.Name + [BaseConfig]::Filename)) @{
	Enabled = $false
	AverageProfit = "45 min"
	EnabledAlgorithms = $null
	DisabledAlgorithms = $null
	SpecifiedCoins = $null
	PartyPassword = $null
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

[decimal] $Pool_Variety = if ($Cfg.Variety) { $Cfg.Variety } else { 0.85 }
# already accounting Aux's
$AuxCoins = @("UIS")

if ($null -eq $Cfg.SpecifiedCoins) {
	$Cfg.SpecifiedCoins = @{ "cnGPU" = "XEQ"; "Equihash144" = "BTCZ"; "Equihash192" = "YEC"; "Hmq1725" = "PLUS"; "Lyra2z330" = "GXX"; "X21s" = "PGN"; "X25x" = "BITC"; "Yescrypt" = "XMY" }
}

try {
	$RequestStatus = Get-Rest "https://api.zergpool.com:8443/api/status"
}
catch { return $PoolInfo }

try {
	$RequestCurrency = Get-Rest "https://api.zergpool.com:8443/api/currencies"
}
catch { return $PoolInfo }

try {
	if (![Config]::UseApiProxy -and $Config.ShowBalance) {
		$RequestBalance = Get-Rest "https://api.zergpool.com:8443/api/wallet?address=$Wallet"
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
	if (!$RequestCurrency.$_.noautotrade -or !($RequestCurrency.$_.noautotrade -eq 1)) {
		[PSCustomObject]@{
			Coin = if (!$RequestCurrency.$_.symbol) { $_ } else { $RequestCurrency.$_.symbol }
			Algo = $RequestCurrency.$_.algo
			Profit = [decimal]$RequestCurrency.$_.estimate / 1050
			Hashrate = $RequestCurrency.$_.hashrate_shared
			BTC24h = $RequestCurrency.$_."24h_btc"
			BTC24hShared = $RequestCurrency.$_."24h_btc_shared"
			BTC24hSolo = $RequestCurrency.$_."24h_btc_solo"
		}
	}
} | Group-Object -Property Algo -AsHashTable

$Pool_Region = "na"
$Regions = @("na", "eu", "asia")
switch ($Config.Region) {
	"$([eRegion]::Europe)" { $Pool_Region = "eu" }
	"$([eRegion]::China)" { $Pool_Region = "asia" }
	"$([eRegion]::Japan)" { $Pool_Region = "asia" }
}
$Regions = $Regions | Sort-Object @{ Expression = { if ($_ -eq $Pool_Region) { 1 } elseif ($_ -eq "na" -or $_ -eq "eu") { 2 } else { 3 } } } |
	Select-Object -First 3

$RequestStatus | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
	$Algo = $RequestStatus.$_
	$Pool_Algorithm = Get-Algo $Algo.name
	if ($Pool_Algorithm -and $Currency."$($Algo.name)" -and $Cfg.DisabledAlgorithms -notcontains $Pool_Algorithm -and
		$Algo.actual_last24h -ne $Algo.estimate_last24h -and [decimal]$Algo.estimate_current -gt 0 -and [decimal]$Algo.hashrate_last24h -gt 0) {
		$Pool_Hosts = $Regions | ForEach-Object { "$($Algo.name).$_.mine.zergpool.com" }
		$Pool_Protocol = "stratum+tcp"
		$Pool_Port = $Algo.port
		$Pool_PortUsecure = $Algo.port
		# Many cpu algos broken on ssl port
		<#if ($Config.SSL -eq $true) {
			$Pool_Protocol = "stratum+ssl"
			$Pool_Port = $Algo.tls_port
		}#>
		$Pool_Diff = if ($AllAlgos.Difficulty.$Pool_Algorithm) { "sd=$($AllAlgos.Difficulty.$Pool_Algorithm)" } else { [string]::Empty }
		$Divisor = 1000000 * $Algo.mbtc_mh_factor
		$CurrencyFiltered = $Currency."$($Algo.name)"

		# convert to one dimension and decimal
		$Algo.actual_last24h_shared = [decimal]$Algo.actual_last24h_shared / 1000
		$Algo.actual_last24h_solo = [decimal]$Algo.actual_last24h_solo / 1000
		# recalc
		$actual = $CurrencyFiltered | Measure-Object "BTC24h", "BTC24hShared", "BTC24hSolo" -Sum
		$Algo.actual_last24h = [decimal][Math]::Min([decimal]$Algo.actual_last24h / 1000, $actual[0].Sum * $Divisor / [decimal]$Algo.hashrate_last24h)
		if ([decimal]$Algo.hashrate_last24h_shared -gt 0) {
			$Algo.actual_last24h_shared = [decimal][Math]::Min($Algo.actual_last24h_shared, $actual[1].Sum * $Divisor / [decimal]$Algo.hashrate_last24h_shared)
		}
		if ([decimal]$Algo.hashrate_last24h_solo -gt 0) {
			$Algo.actual_last24h_solo = [decimal][Math]::Min($Algo.actual_last24h_solo, $actual[2].Sum * $Divisor / [decimal]$Algo.hashrate_last24h_solo)
		}
		$Algo.estimate_current = [decimal][Math]::Min([decimal]$Algo.estimate_current / 1.05, ($CurrencyFiltered | Measure-Object "Profit" -Maximum)[0].Maximum)
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
					$solo = $Cfg.SpecifiedCoins.$Pool_Algorithm -contains "solo"
					$party = $Cfg.SpecifiedCoins.$Pool_Algorithm -contains "party"
					$party_pass = $Cfg.PartyPassword
					if ([string]::IsNullOrWhiteSpace($party_pass)) {
						$party_pass = "MindMiner";
						if ($party) {
							Write-Host "The `"$party_pass`" party password is used. You can set `"PartyPassword`" variable in the '$($PoolInfo.Name).config.txt'." -ForegroundColor Yellow
						}
					}
					$spsign = if ($solo -or $party) { "*" } else { [string]::Empty }
					$spstr = if ($solo) { "m=solo" } elseif ($party) { "m=party.$party_pass" } else { [string]::Empty }
					$spkey = if ($solo) { "_solo" } elseif ($party) { "_party" } else { [string]::Empty }

					$actual_last24 = if ($spsign) { $Algo.actual_last24h_solo } else { $Algo.actual_last24h_shared }
					[decimal] $Profit = ([Math]::Min($_.Profit, $actual_last24) + $_.Profit) / 2
					$Profit = $Profit * (1 - [decimal]$Algo.fees / 100) * $Pool_Variety / $Divisor
					$ProfitFast = $Profit
					if ($Profit -gt 0) {
						$Profit = Set-Stat -Filename $PoolInfo.Name -Key "$Pool_Algorithm`_$($_.Coin)$spkey" -Value $Profit -Interval $Cfg.AverageProfit
					}

					if ([int]$Algo.workers_shared -ge $Config.MinimumMiners -or $global:HasConfirm -or $spsign) {
						$PoolInfo.Algorithms.Add([PoolAlgorithmInfo] @{
							Name = "$($PoolInfo.Name)-$($Pool_Region.ToUpper())"
							Algorithm = $Pool_Algorithm
							Profit = if (($Config.Switching -as [eSwitching]) -eq [eSwitching]::Fast) { $ProfitFast } else { $Profit }
							Info = (Get-Join "/" $coins) + "*" + $spsign
							InfoAsKey = $true
							Protocol = $Pool_Protocol
							Hosts = $Pool_Hosts
							Port = $Pool_Port
							PortUnsecure = $Pool_PortUsecure
							User = ([Config]::WalletPlaceholder -f $sgn)
							Password = Get-Join "," @("c=$sgn", "mc=$(Get-Join "/" $coins)", $spstr, $Pool_Diff, [Config]::WorkerNamePlaceholder)
							Priority = if ($spsign) { [Priority]::Solo } elseif ($AllAlgos.EnabledAlgorithms -contains $Pool_Algorithm -or $Cfg.EnabledAlgorithms -contains $Pool_Algorithm) { [Priority]::High } else { [Priority]::Normal }
						})
					}
				}
			}
		}

		if ($MaxCoin -and $MaxCoin.Profit -gt 0 -and $Cfg.SpecifiedCoins.$Pool_Algorithm -notcontains "only" -and
			$Cfg.SpecifiedCoins.$Pool_Algorithm -notcontains "solo" -and $Cfg.SpecifiedCoins.$Pool_Algorithm -notcontains "party") {
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

			if ([int]$Algo.workers_shared -ge $Config.MinimumMiners -or $global:HasConfirm) {
				$PoolInfo.Algorithms.Add([PoolAlgorithmInfo] @{
					Name = "$($PoolInfo.Name)-$($Pool_Region.ToUpper())"
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