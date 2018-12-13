<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::UseApiProxy) { return $null }

$PoolInfo = [PoolInfo]::new()
$PoolInfo.Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreatePoolConfig "Do you want to mine on $($PoolInfo.Name) (>0.0025 BTC every 5H, >0.0015 BTC sunday)" ([IO.Path]::Combine($PSScriptRoot, $PoolInfo.Name + [BaseConfig]::Filename)) @{
	Enabled = $false
	AverageProfit = "45 min"
	EnabledAlgorithms = $null
	DisabledAlgorithms = $null
	SpecifiedCoins = $null
}
if ($global:AskPools -eq $true -or !$Cfg) { return $null }

$Sign = "BTC"
$wallets = $Config.Wallet | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object { "$_" -ne "NiceHash" }
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

[decimal] $Pool_Variety = if ($Cfg.Variety) { $Cfg.Variety } else { 0.75 }
# already accounting Aux's
$AuxCoins = @("UIS", "MBL")
<#
if ($Cfg.SpecifiedCoins -eq $null) {
	$Cfg.SpecifiedCoins = @{ "Lyra2z" = "GIN"; "Phi" = "FLM"; "Skein" = "DGB"; "Tribus" = "DNR"; "X16r" = "RVN"; "X16s" = "PGN"; "X17" = "XVG"; "Yescryptr16" = "CRP" }
}
#>
try {
	$RequestStatus = Get-UrlAsJson "http://blockmasters.co/api/status"
}
catch { return $PoolInfo }
<#
try {
	$RequestCurrency = Get-UrlAsJson "http://blockmasters.co/api/currencies"
}
catch { return $PoolInfo }
#>
try {
	if ($Config.ShowBalance) {
		$RequestBalance = Get-UrlAsJson "http://blockmasters.co/api/walletEx?address=$Wallet"
	}
}
catch { }
<#
try {
	$24HFile = [IO.Path]::Combine($PSScriptRoot, "BlockMasters.24h.Fix.txt")
	$24HStat = [BaseConfig]::Read($24HFile)
	if (!$24HStat -or ([datetime]::UtcNow - $24HStat.Change).TotalMinutes -gt 10) {
		if (Get-UrlAsFile "http://mindminer.online/ftp/BlockMasters.24h.Fix.txt" $24HFile) {
			$24HStat = [BaseConfig]::Read($24HFile)
			if ($24HStat -and ([datetime]::UtcNow - $24HStat.Change).TotalMinutes -gt 10) {
				$24HStat = $null
			}
		}
	}
}
catch { }
#>
if (!$RequestStatus<# -or !$RequestCurrency#>) { return $PoolInfo }
$PoolInfo.HasAnswer = $true
$PoolInfo.AnswerTime = [DateTime]::Now

if ($RequestBalance) {
	$PoolInfo.Balance.Add($Sign, [BalanceInfo]::new([decimal]($RequestBalance.balance), [decimal]($RequestBalance.unsold)))
}
<#
$Currency = $RequestCurrency | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
	[PSCustomObject]@{
		Coin = if (!$RequestCurrency.$_.symbol) { $_ } else { $RequestCurrency.$_.symbol }
		Algo = $RequestCurrency.$_.algo
		Profit = [decimal]$RequestCurrency.$_.estimate / 1000
		Hashrate = $RequestCurrency.$_.hashrate 
		Enabled = $RequestCurrency.$_.hashrate -gt 0
	}
}
#>

$Pool_Host = "blockmasters.co"
switch ($Config.Region) {
	"$([eRegion]::Europe)" { $Pool_Host = "eu.blockmasters.co" }
}

$RequestStatus | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
	$Algo = $RequestStatus.$_
	$Pool_Algorithm = Get-Algo($Algo.name)
	if ($Pool_Algorithm -and (!$Cfg.EnabledAlgorithms -or $Cfg.EnabledAlgorithms -contains $Pool_Algorithm) -and $Cfg.DisabledAlgorithms -notcontains $Pool_Algorithm -and
		$Algo.actual_last24h -ne $Algo.estimate_last24h -and [decimal]$Algo.estimate_current -gt 0) {
		$Pool_Port = $Algo.port
		$Pool_Diff = if ($AllAlgos.Difficulty.$Pool_Algorithm) { "d=$($AllAlgos.Difficulty.$Pool_Algorithm)" } else { [string]::Empty }
		$Divisor = 1000000 * $Algo.mbtc_mh_factor

		# convert to one dimension and decimal
<#		$Algo.actual_last24h = [decimal]$Algo.actual_last24h
		if ($24HStat -and $24HStat."$Pool_Algorithm") {
			$Algo.actual_last24h = [Math]::Min([decimal]$24HStat."$Pool_Algorithm" * $Algo.mbtc_mh_factor, $Algo.actual_last24h)
		}
		else {
			$Algo.actual_last24h *= 0.8
		}#>
		$Algo.actual_last24h = [decimal]$Algo.actual_last24h / 1000
		$Algo.estimate_current = [decimal]$Algo.estimate_current
		# fix very high or low daily changes
		if ($Algo.estimate_current -gt $Algo.actual_last24h * [Config]::MaxTrustGrow) { $Algo.estimate_current = $Algo.actual_last24h * [Config]::MaxTrustGrow }
		if ($Algo.actual_last24h -gt $Algo.estimate_current * [Config]::MaxTrustGrow) { $Algo.actual_last24h = $Algo.estimate_current * [Config]::MaxTrustGrow }

		<#
		# find more profit coin in algo
		$MaxCoin = $null;

		$CurrencyFiltered = $Currency | Where-Object { $_.Algo -eq $Algo.name -and $_.Profit -gt 0 -and $_.Enabled }
		$CurrencyFiltered | ForEach-Object {
			if ($_.Profit -gt $Algo.estimate_current * [Config]::MaxTrustGrow) { $_.Profit = $Algo.estimate_current * [Config]::MaxTrustGrow }
			if ($MaxCoin -eq $null -or $_.Profit -gt $MaxCoin.Profit) { $MaxCoin = $_ }

			if ($Cfg.SpecifiedCoins.$Pool_Algorithm -eq $_.Coin -or $Cfg.SpecifiedCoins.$Pool_Algorithm -contains $_.Coin) {
				[decimal] $Profit = ([Math]::Min($_.Profit, $Algo.actual_last24h) + $_.Profit) / 2
				$Profit = $Profit * (1 - [decimal]$Algo.fees / 100) * $Pool_Variety / $Divisor
				$ProfitFast = $Profit
				if ($Profit -gt 0) {
					$Profit = Set-Stat -Filename $PoolInfo.Name -Key "$Pool_Algorithm`_$($_.Coin)" -Value $Profit -Interval $Cfg.AverageProfit
				}

				if ([int]$Algo.workers -ge $Config.MinimumMiners -or $global:HasConfirm) {
					$PoolInfo.Algorithms.Add([PoolAlgorithmInfo] @{
						Name = $PoolInfo.Name
						Algorithm = $Pool_Algorithm
						Profit = if (($Config.Switching -as [eSwitching]) -eq [eSwitching]::Fast) { $ProfitFast } else { $Profit }
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
		}

		if ($MaxCoin -and $MaxCoin.Profit -gt 0 -and $Cfg.SpecifiedCoins.$Pool_Algorithm -notcontains "only") {
			if ($Algo.estimate_current -gt $MaxCoin.Profit) { $Algo.estimate_current = $MaxCoin.Profit }

			[decimal] $CurrencyAverage = ($CurrencyFiltered | Where-Object { !$AuxCoins.Contains($_.Coin) } |
				Select-Object @{ Label = "Profit"; Expression= { $_.Profit * $_.Hashrate }} |
				Measure-Object -Property Profit -Sum).Sum / ($CurrencyFiltered |
				Where-Object { !$AuxCoins.Contains($_.Coin) } | Measure-Object -Property Hashrate -Sum).Sum
			# $CurrencyAverage += ($CurrencyFiltered | Where-Object { $AuxCoins.Contains($_.Coin) } | Measure-Object -Property Profit -Sum).Sum
		#>
			[decimal] $Profit = ([Math]::Min($Algo.estimate_current, $Algo.actual_last24h) + $Algo.estimate_current * ((101 - $Algo.coins) / 100)) / 2
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
					#Info = $MaxCoin.Coin
					Protocol = "stratum+tcp"
					Host = $Pool_Host
					Port = $Pool_Port
					PortUnsecure = $Pool_Port
					User = ([Config]::WalletPlaceholder -f $Sign)
					Password = Get-Join "," @("c=$Sign", $Pool_Diff, [Config]::WorkerNamePlaceholder)
				})
			}
		#}
	}
}

Remove-Stat -Filename $PoolInfo.Name -Interval $Cfg.AverageProfit

$PoolInfo