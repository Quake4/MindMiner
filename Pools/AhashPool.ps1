<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Include.ps1

$PoolInfo = [PoolInfo]::new()
$PoolInfo.Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateConfig "Do you want to mine on $($PoolInfo.Name) (>0.008 BTC every 24H, <0.005 BTC ~ weekly)" ([IO.Path]::Combine($PSScriptRoot, $PoolInfo.Name + [BaseConfig]::Filename)) @{
	Enabled = $false
	AverageProfit = "1 hour 30 min"
}
if (!$Cfg) { return $PoolInfo }
if (!$Config.Wallet.BTC) { return $PoolInfo }

$PoolInfo.Enabled = $Cfg.Enabled
$PoolInfo.AverageProfit = $Cfg.AverageProfit

if (!$Cfg.Enabled) { return $PoolInfo }

[decimal] $Pool_Variety = 0.70
[decimal] $Pool_OneCoinVariety = 0.80
# already accounting Aux's
$AuxCoins = @(<#"UIS", "MBL"#>)
[decimal] $DifFactor = 2

try {
	$RequestStatus = Get-UrlAsJson "https://www.ahashpool.com/api/status"
}
catch { return $PoolInfo }

try {
	$RequestCurrency = Get-UrlAsJson "https://www.ahashpool.com/api/currencies/"
}
catch { return $PoolInfo }

try {
	$RequestBalance = Get-UrlAsJson "https://www.ahashpool.com/api/wallet?address=$($Config.Wallet.BTC)"
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
	[PSCustomObject]@{
		Coin = if (!$RequestCurrency.$_.symbol) { $_ } else { $RequestCurrency.$_.symbol }
		Algo = $RequestCurrency.$_.algo
		Profit = [decimal]$RequestCurrency.$_.estimate / 1000
	}
}

$RequestStatus | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
	$Pool_Algorithm = Get-Algo($RequestStatus.$_.name)
	if ($Pool_Algorithm) {
		$Pool_Host = "$($RequestStatus.$_.name).mine.ahashpool.com"
		$Pool_Port = $RequestStatus.$_.port

		$Divisor = 1000000
		
		switch ($Pool_Algorithm) {
			"blake" { $Divisor *= 1000 }
			"blake2s" { $Divisor *= 1000 }
			"blakecoin" { $Divisor *= 1000 }
			# "decred" { $Divisor *= 1000 }
			"equihash" { $Divisor /= 1000 }
			# "keccak" { $Divisor *= 1000 }
			# "keccakc" { $Divisor *= 1000 }
			"nist5" { $Divisor *= 3 }
			"qubit" { $Divisor *= 1000 }
			"x11" { $Divisor *= 1000 }
			"yescrypt" { $Divisor /= 1000 }
		}

		# find more profit coin in algo
		$Algo = $RequestStatus.$_
		$CurrencyFiltered = $Currency | Where-Object { $_.Algo -eq $Algo.name -and $_.Profit -gt 0 }
		$MaxCoin = $null;
		$MaxCoinProfit = $null
		[decimal] $AuxProfit = 0
		[decimal] $Variety = $Pool_Variety
		if (($CurrencyFiltered -is [array] -and $CurrencyFiltered.Length -eq 1) -or $CurrencyFiltered -is [PSCustomObject]) {
			$Variety = $Pool_OneCoinVariety
		}
		# convert to one dimension and decimal
		$Algo.actual_last24h = [decimal]$Algo.actual_last24h / 1000
		$Algo.estimate_last24h = [decimal]$Algo.estimate_last24h
		$Algo.estimate_current = [decimal]$Algo.estimate_current
		$CurrencyFiltered | ForEach-Object {
			$prof = $_.Profit
			# try to fix error in output profit
			if ($Algo.actual_last24h -gt 0 -and $Algo.estimate_last24h -gt $Algo.actual_last24h * $DifFactor) { $Algo.estimate_last24h = $Algo.actual_last24h }
			if ($prof -gt $Algo.estimate_last24h * $DifFactor) { $prof = $Algo.estimate_last24h }

			$Profit = $prof * 0.30 + $Algo.estimate_last24h * 0.70

			if ($MaxCoin -eq $null -or $_.Profit -gt $MaxCoin.Profit) {
				$MaxCoin = $_
				$MaxCoinProfit = $Profit
			}

			if ($AuxCoins.Contains($_.Coin)) {
				$AuxProfit += $prof
			}
		}

		if ($MaxCoinProfit -gt 0 -and $Algo.estimate_current -gt 0) {
			if ($Algo.estimate_current -gt $MaxCoinProfit * $DifFactor) { $Algo.estimate_current = $MaxCoinProfit }
			$MaxCoinProfit = [Math]::Min($MaxCoinProfit + $AuxProfit, $Algo.estimate_current) * (1 - [decimal]$Algo.fees / 100) * $Variety / $Divisor
			$MaxCoinProfit = Set-Stat -Filename ($PoolInfo.Name) -Key $Pool_Algorithm -Value $MaxCoinProfit -Interval $Cfg.AverageProfit

			$PoolInfo.Algorithms.Add([PoolAlgorithmInfo] @{
				Name = $PoolInfo.Name
				Algorithm = $Pool_Algorithm
				Profit = $MaxCoinProfit
				Info = $MaxCoin.Coin
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
