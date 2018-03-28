<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Include.ps1

$PoolInfo = [PoolInfo]::new()
$PoolInfo.Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateConfig "Do you want to mine on $($PoolInfo.Name) (>0.008 BTC every 12H, <0.004 BTC sunday)" ([IO.Path]::Combine($PSScriptRoot, $PoolInfo.Name + [BaseConfig]::Filename)) @{
	Enabled = $false
	AverageProfit = "1 hour 30 min"
	SpecifiedCoins = $null
}
if (!$Cfg) { return $PoolInfo }
if (!$Config.Wallet.BTC) { return $PoolInfo }

$PoolInfo.Enabled = $Cfg.Enabled
$PoolInfo.AverageProfit = $Cfg.AverageProfit

if (!$Cfg.Enabled) { return $PoolInfo }

[decimal] $Pool_Variety = 0.80
# already accounting Aux's
$AuxCoins = @("UIS", "MBL")
[decimal] $DifFactor = 1.5

if ($Cfg.SpecifiedCoins -eq $null) {
	$Cfg.SpecifiedCoins = @{ "C11" = "SPD"; "Phi" = "LUX"; "Skein" = "ULT"; "X17" = "XVG"; "Xevan" = "XLR" }
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
	if ($Config.ShowBalance) {
		$RequestBalance = Get-UrlAsJson "http://api.zergpool.com:8080/api/wallet?address=$($Config.Wallet.BTC)"
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
		}
	}
}

$RequestStatus | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
	$Pool_Algorithm = Get-Algo($RequestStatus.$_.name)
	if ($Pool_Algorithm -and [decimal]$RequestStatus.$_.actual_last24h -gt 0 -and [decimal]$RequestStatus.$_.estimate_current -gt 0) {
		$Pool_Host = $RequestStatus.$_.name + ".mine.zergpool.com"
		$Pool_Port = $RequestStatus.$_.port

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
		$Algo.actual_last24h = [decimal]$Algo.actual_last24h / 1000
		$Algo.estimate_last24h = [decimal]$Algo.estimate_last24h
		$Algo.estimate_current = [decimal]$Algo.estimate_current
		# fix very high or low daily changes
		if ($Algo.estimate_last24h -gt $Algo.actual_last24h * $DifFactor) { $Algo.estimate_last24h = $Algo.actual_last24h * $DifFactor }
		if ($Algo.actual_last24h -gt $Algo.estimate_last24h * $DifFactor) { $Algo.actual_last24h = $Algo.estimate_last24h * $DifFactor }
		if ($Algo.estimate_last24h -gt $Algo.estimate_current * $DifFactor) { $Algo.estimate_last24h = $Algo.estimate_current * $DifFactor }
		
		# find more profit coin in algo
		$MaxCoin = $null;
		$HasSpecificCoin = $false

		$CurrencyFiltered = $Currency | Where-Object { $_.Algo -eq $Algo.name -and $_.Profit -gt 0 }
		$CurrencyFiltered | ForEach-Object {
			if ($_.Profit -gt $Algo.estimate_last24h * $DifFactor) { $_.Profit = $Algo.estimate_last24h * $DifFactor }
			if ($MaxCoin -eq $null -or $_.Profit -gt $MaxCoin.Profit) { $MaxCoin = $_ }

			if ($Cfg.SpecifiedCoins."$Pool_Algorithm" -eq $_.Coin -or $Cfg.SpecifiedCoins."$Pool_Algorithm" -contains $_.Coin) {
				$HasSpecificCoin = $true

				[decimal] $Profit = $_.Profit * [Config]::CurrentOf24h + [Math]::Sqrt($Algo.estimate_last24h * $Algo.actual_last24h) * (1 - [Config]::CurrentOf24h)
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
					User = $Config.Wallet.BTC
					Password = "c=BTC,mc=$($_.Coin),$($Config.WorkerName)" # "c=$($MaxCoin.Coin),$($Config.WorkerName)";
				})
			}
		}

		if ($MaxCoin -and $MaxCoin.Profit -gt 0) {
			[decimal] $Profit = $MaxCoin.Profit
			if ($Algo.estimate_current -gt $Profit * $DifFactor) { $Algo.estimate_current = $Profit * $DifFactor }

			[decimal] $CurrencyAverage = ($CurrencyFiltered | Where-Object { !$AuxCoins.Contains($_.Coin) } | Measure-Object -Property Profit -Average).Average
			# $CurrencyAverage += ($CurrencyFiltered | Where-Object { $AuxCoins.Contains($_.Coin) } | Measure-Object -Property Profit -Sum).Sum

			$Profit = ($Algo.estimate_current + $CurrencyAverage) / 2 * [Config]::CurrentOf24h + [Math]::Sqrt($Algo.estimate_last24h * $Algo.actual_last24h) * (1 - [Config]::CurrentOf24h)
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
				User = $Config.Wallet.BTC
				Password = "c=BTC,$($Config.WorkerName)" # "c=$($MaxCoin.Coin),$($Config.WorkerName)";
			})
		}
	}
}

$PoolInfo