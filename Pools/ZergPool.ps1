<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Include.ps1

if ([Config]::UseApiProxy) { return $null }

$PoolInfo = [PoolInfo]::new()
$PoolInfo.Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateConfig "Do you want to mine on $($PoolInfo.Name) (>0.008 BTC every 12H, <0.004 BTC sunday)" ([IO.Path]::Combine($PSScriptRoot, $PoolInfo.Name + [BaseConfig]::Filename)) @{
	Enabled = $false
	AverageProfit = "1 hour 30 min"
	EnabledAlgorithms = $null
	DisabledAlgorithms = $null
	SpecifiedCoins = $null
}
if (!$Cfg) { return $PoolInfo }
if (!$Config.Wallet.BTC -and !$Config.Wallet.LTC) { return $PoolInfo }

$Wallet = if ($Config.Wallet.LTC) { $Config.Wallet.LTC } else { $Config.Wallet.BTC }
$Sign = if ($Config.Wallet.LTC) { "LTC" } else { "BTC" }

$PoolInfo.Enabled = $Cfg.Enabled
$PoolInfo.AverageProfit = $Cfg.AverageProfit

if (!$Cfg.Enabled) { return $PoolInfo }

[decimal] $Pool_Variety = 0.80
# already accounting Aux's
$AuxCoins = @("UIS", "MBL")
$SecondPorts = @{ 3636 = 3637; 3737 = 3738 }

if ($Cfg.SpecifiedCoins -eq $null) {
	$Cfg.SpecifiedCoins = @{ "C11" = "SPD"; "Phi" = "LUX"; "Skein" = "ULT"; "X16r" = "RVN"; "X17" = "XVG"; "Xevan" = "XLR" }
}

try {
	$RequestStatus = Get-UrlAsJson "http://api.zergpool.com:8080/api/status"
}
catch { return $PoolInfo }

try {
	$RequestCurrency = Get-UrlAsJson "http://api.zergpool.com:8080/api/currencies"
}
catch { return $PoolInfo }

try {
	if ($Config.ShowBalance -and $Config.Wallet.BTC) {
		$RequestBalance = Get-UrlAsJson "http://api.zergpool.com:8080/api/wallet?address=$($Config.Wallet.BTC)"
	}
}
catch { }

try {
	$24HFile = [IO.Path]::Combine($PSScriptRoot, "ZergPool.24Profit.txt")
	$24HStat = [BaseConfig]::Read($24HFile)
	if (!$24HStat -or ([datetime]::UtcNow - $24HStat.Change).TotalMinutes -gt 10) {
		if (Get-UrlAsFile "http://mindminer.online/ftp/ZergPool.24Profit.txt" $24HFile) {
			$24HStat = [BaseConfig]::Read($24HFile)
			if ($24HStat -and ([datetime]::UtcNow - $24HStat.Change).TotalMinutes -gt 10) {
				$24HStat = $null
			}
		}
	}
}
catch { }

if (!$RequestStatus -or !$RequestCurrency) { return $PoolInfo }
$PoolInfo.HasAnswer = $true
$PoolInfo.AnswerTime = [DateTime]::Now

if ($RequestBalance) {
	$PoolInfo.Balance.Value = [decimal]($RequestBalance.balance)
	$PoolInfo.Balance.Additional = [decimal]($RequestBalance.unsold)
}

# if ($Config.SSL -eq $true) { $Pool_Protocol = "stratum+ssl" } else { $Pool_Protocol = "stratum+tcp" }

$Currency = $RequestCurrency | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
	if (!$RequestCurrency.$_.noautotrade -or !($RequestCurrency.$_.noautotrade -eq 1)) {
		[PSCustomObject]@{
			Coin = if (!$RequestCurrency.$_.symbol) { $_ } else { $RequestCurrency.$_.symbol }
			Algo = $RequestCurrency.$_.algo
			Profit = [decimal]$RequestCurrency.$_.estimate / 1000
			Enabled = $RequestCurrency.$_.hashrate -gt 0
		}
	}
}

$RequestStatus | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
	$Pool_Algorithm = Get-Algo($RequestStatus.$_.name)
	if ($Pool_Algorithm -and (!$Cfg.EnabledAlgorithms -or $Cfg.EnabledAlgorithms -contains $Pool_Algorithm) -and $Cfg.DisabledAlgorithms -notcontains $Pool_Algorithm -and
		$RequestStatus.$_.actual_last24h -ne $RequestStatus.$_.estimate_last24h -and [decimal]$RequestStatus.$_.actual_last24h -gt 0 -and [decimal]$RequestStatus.$_.estimate_current -gt 0) {
		$Pool_Host = $RequestStatus.$_.name + ".mine.zergpool.com"
		$Pool_Port = if ($SecondPorts[$RequestStatus.$_.port]) { $SecondPorts[$RequestStatus.$_.port] } else { $RequestStatus.$_.port }
		$Pool_Diff = if ($AllAlgos.Difficulty.$Pool_Algorithm) { "d=$($AllAlgos.Difficulty.$Pool_Algorithm)" } else { [string]::Empty }

		$Divisor = 1000000
		switch ($Pool_Algorithm) {
			"blake" { $Divisor *= 1000 }
			"blake2s" { $Divisor *= 1000 }
			"blakecoin" { $Divisor *= 1000 }
			# "decred" { $Divisor *= 1000 }
			"equihash" { $Divisor /= 1000 }
			"keccak" { $Divisor *= 1000 }
			"keccakc" { $Divisor *= 1000 }
			"nist5" { $Divisor *= 3 }
			"qubit" { $Divisor *= 1000 }
			"x11" { $Divisor *= 1000 }
			"yescrypt" { $Divisor /= 1000 }
			"yescryptr16" { $Divisor /= 1000 }
		}

		# convert to one dimension and decimal
		$Algo = $RequestStatus.$_
		$Algo.actual_last24h = [decimal]$Algo.actual_last24h
		$Algo.estimate_last24h = [decimal]$Algo.estimate_last24h
		$Algo.estimate_current = [decimal]$Algo.estimate_current
		if ($24HStat -and $24HStat."$Pool_Algorithm") {
			$Algo.actual_last24h = [Math]::Min([decimal]$24HStat."$Pool_Algorithm" * $Divisor / 1000000, $Algo.actual_last24h)
		}
		else {
			$Algo.actual_last24h *= 0.9
		}
		$Algo.actual_last24h = $Algo.actual_last24h / 1000
		# fix very high or low daily changes
		if ($Algo.estimate_last24h -gt $Algo.actual_last24h * [Config]::MaxTrustGrow) { $Algo.estimate_last24h = $Algo.actual_last24h * [Config]::MaxTrustGrow }
		if ($Algo.actual_last24h -gt $Algo.estimate_last24h * [Config]::MaxTrustGrow) { $Algo.actual_last24h = $Algo.estimate_last24h * [Config]::MaxTrustGrow }
		if ($Algo.estimate_last24h -gt $Algo.estimate_current * [Config]::MaxTrustGrow) { $Algo.estimate_last24h = $Algo.estimate_current * [Config]::MaxTrustGrow }
		
		# find more profit coin in algo
		$MaxCoin = $null;
		$HasSpecificCoin = $false

		$CurrencyFiltered = $Currency | Where-Object { $_.Algo -eq $Algo.name -and $_.Profit -gt 0 }
		$CurrencyFiltered | ForEach-Object {
			if ($_.Profit -gt $Algo.estimate_last24h * [Config]::MaxTrustGrow) { $_.Profit = $Algo.estimate_last24h * [Config]::MaxTrustGrow }
			if ($MaxCoin -eq $null -or $_.Profit -gt $MaxCoin.Profit) { $MaxCoin = $_ }

			if ($Cfg.SpecifiedCoins.$Pool_Algorithm -eq $_.Coin -or $Cfg.SpecifiedCoins.$Pool_Algorithm -contains $_.Coin) {
				$HasSpecificCoin = $true

				[decimal] $Profit = $_.Profit * [Config]::CurrentOf24h + ([Math]::Min($Algo.estimate_last24h, $Algo.actual_last24h) + $Algo.actual_last24h) / 2 * (1 - [Config]::CurrentOf24h)
				$Profit = $Profit * (1 - [decimal]$Algo.fees / 100) * $Pool_Variety / $Divisor
				$Profit = Set-Stat -Filename ($PoolInfo.Name) -Key "$Pool_Algorithm`_$($_.Coin)" -Value $Profit -Interval $Cfg.AverageProfit

				$PoolInfo.Algorithms.Add([PoolAlgorithmInfo] @{
					Name = $PoolInfo.Name
					Algorithm = $Pool_Algorithm
					Profit = $Profit
					Info = $_.Coin + "*"
					InfoAsKey = $HasSpecificCoin
					Protocol = "stratum+tcp" # $Pool_Protocol
					Host = $Pool_Host
					Port = $Pool_Port
					PortUnsecure = $Pool_Port
					User = $Wallet
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
				Info = if (!$HasSpecificCoin -or $CurrencyFiltered -is [PSCustomObject]) { $MaxCoin.Coin } else { [string]::Empty }
				InfoAsKey = $HasSpecificCoin
				Protocol = "stratum+tcp" # $Pool_Protocol
				Host = $Pool_Host
				Port = $Pool_Port
				PortUnsecure = $Pool_Port
				User = $Wallet
				Password = Get-Join "," @("c=$Sign", $Pool_Diff, [Config]::WorkerNamePlaceholder)
			})
		}
	}
}

$PoolInfo