<#
MindMiner  Copyright (C) 2018-2022  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::UseApiProxy) { return $null }
if (!$Config.Wallet) { return $null }

$PoolInfo = [PoolInfo]::new()
$PoolInfo.Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

# $Cfg = ReadOrCreatePoolConfig "Do you want to mine on $($PoolInfo.Name) (>0.0025 BTC every day)" ([IO.Path]::Combine($PSScriptRoot, $PoolInfo.Name + [BaseConfig]::Filename)) @{
$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $PoolInfo.Name + [BaseConfig]::Filename), @{
	Enabled = $false
	AverageProfit = "45 min"
	EnabledAlgorithms = $null
	DisabledAlgorithms = $null
	SpecifiedCoins = $null
	PartyPassword = $null
})
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

[decimal] $Pool_Variety = if ($Cfg.Variety) { $Cfg.Variety } else { 0.80 }
# already accounting Aux's
$AuxCoins = @("UIS")
$PartySoloExlude = @( "X25x" )

if ($null -eq $Cfg.SpecifiedCoins) {
	$Cfg.SpecifiedCoins = @{ "Hmq1725" = "PLUS1"; "Lyra2v3" = "VTC"; "Phi2" = "AGM"; "Skein" = "DGB"; "Skunk" = "HDAC"; "X21s" = "PGN"; "Xevan" = "BSD"; "Yescrypt" = "XMY" }
}

try {
	$RequestStatus = Get-Rest "http://blockmasters.co/api/status"
}
catch { return $PoolInfo }

try {
	$RequestCurrency = Get-Rest "http://blockmasters.co/api/currencies"
}
catch { return $PoolInfo }

try {
	if ($Config.ShowBalance) {
		$RequestBalance = Get-Rest "http://blockmasters.co/api/walletEx?address=$Wallet"
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
		Algo = $RequestCurrency.$_.algo.ToLower()
		Profit = [decimal]$RequestCurrency.$_.estimate / 1000
		Hashrate = $RequestCurrency.$_.hashrate 
		BTC24h = $RequestCurrency.$_."24h_btc"
	}
} | Group-Object -Property Algo -AsHashTable

$Pool_Region = "NA"
$Pool_Hosts = @("blockmasters.co", "eu.blockmasters.co", "as.blockmasters.co")
switch ($Config.Region) {
	"$([eRegion]::Europe)" { $Pool_Region = "EU"; $Pool_Hosts = @("eu.blockmasters.co", "blockmasters.co", "as.blockmasters.co") }
	"$([eRegion]::China)" { $Pool_Region = "AS"; $Pool_Hosts = @("as.blockmasters.co", "blockmasters.co", "eu.blockmasters.co") }
	"$([eRegion]::Japan)" { $Pool_Region = "AS"; $Pool_Hosts = @("as.blockmasters.co", "blockmasters.co", "eu.blockmasters.co") }
}

$RequestStatus | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
	$Algo = $RequestStatus.$_
	$Pool_Algorithm = Get-Algo $Algo.name
	if ($Pool_Algorithm -and $Currency."$($Algo.name)" -and $Cfg.DisabledAlgorithms -notcontains $Pool_Algorithm -and
		$Algo.actual_last24h -ne $Algo.estimate_last24h -and [decimal]$Algo.estimate_current -gt 0 -and [decimal]$Algo.hashrate_last24h -gt 0) {
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

			if ($PartySoloExlude -notcontains $Algo.name -and ($Cfg.SpecifiedCoins.$Pool_Algorithm -eq $_.Coin -or $Cfg.SpecifiedCoins.$Pool_Algorithm -contains $_.Coin)) {
				$solo = $Cfg.SpecifiedCoins.$Pool_Algorithm -contains "solo"
				$party = $Cfg.SpecifiedCoins.$Pool_Algorithm -contains "party" -and ![string]::IsNullOrWhiteSpace($Cfg.PartyPassword)
				$spsign = if ($solo -or $party) { "*" } else { [string]::Empty }
				$spstr = if ($solo) { "m=solo" } elseif ($party) { "m=party.$($Cfg.PartyPassword)" } else { [string]::Empty }
				$spkey = if ($solo) { "_solo" } elseif ($party) { "_party" } else { [string]::Empty }
			
				[decimal] $Profit = ([Math]::Min($_.Profit, $Algo.actual_last24h) + $_.Profit) / 2
				$Profit = $Profit * (1 - [decimal]$Algo.fees / 100) * $Pool_Variety / $Divisor
				$ProfitFast = $Profit
				if ($Profit -gt 0) {
					$Profit = Set-Stat -Filename $PoolInfo.Name -Key "$Pool_Algorithm`_$($_.Coin)$spkey" -Value $Profit -Interval $Cfg.AverageProfit
				}

				if ([int]$Algo.workers -ge $Config.MinimumMiners -or $global:HasConfirm) {
					$PoolInfo.Algorithms.Add([PoolAlgorithmInfo] @{
						Name = "$($PoolInfo.Name)-$($Pool_Region.ToUpper())"
						Algorithm = $Pool_Algorithm
						Profit = if (($Config.Switching -as [eSwitching]) -eq [eSwitching]::Fast) { $ProfitFast } else { $Profit }
						Info = $_.Coin + "*" + $spsign
						InfoAsKey = $true
						Protocol = "stratum+tcp"
						Hosts = $Pool_Hosts
						Port = $Pool_Port
						PortUnsecure = $Pool_Port
						User = ([Config]::WalletPlaceholder -f $Sign)
						Password = Get-Join "," @("c=$Sign", "mc=$($_.Coin)", $spstr, $Pool_Diff, [Config]::WorkerNamePlaceholder)
						Priority = if ($spsign) { [Priority]::Solo } elseif ($AllAlgos.EnabledAlgorithms -contains $Pool_Algorithm -or $Cfg.EnabledAlgorithms -contains $Pool_Algorithm) { [Priority]::High } else { [Priority]::Normal }
					})
				}
			}
		}

		if ($MaxCoin -and $MaxCoin.Profit -gt 0 -and ($Cfg.SpecifiedCoins.$Pool_Algorithm -notcontains "only" -or $PartySoloExlude -contains $Algo.name)) {
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