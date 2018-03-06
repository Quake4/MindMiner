<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Include.ps1

$PoolInfo = [PoolInfo]::new()
$PoolInfo.Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateConfig "Do you want to mine on $($PoolInfo.Name) (>0.01 BTC every 12H, <0.005 BTC - sunday)" ([IO.Path]::Combine($PSScriptRoot, $PoolInfo.Name + [BaseConfig]::Filename)) @{
	Enabled = $false
	AverageProfit = "1 hour 30 min"
}
if (!$Cfg) { return $PoolInfo }
if (!$Config.Wallet.BTC) { return $PoolInfo }

$PoolInfo.Enabled = $Cfg.Enabled
$PoolInfo.AverageProfit = $Cfg.AverageProfit

if (!$Cfg.Enabled) { return $PoolInfo }

$Pool_Variety = 0.70
$Pool_OneCoinVariety = 0.80
# already accounting Aux's
$AuxCoins = @(<#"UIS", "MBL"#>)

try {
	$RequestStatus = Get-UrlAsJson "http://api.zergpool.com:8080/api/status"
}
catch { return $PoolInfo }

try {
	$RequestCurrency = Get-UrlAsJson "http://api.zergpool.com:8080/api/currencies"
}
catch { return $PoolInfo }

try {
	$RequestBalance = Get-UrlAsJson "http://api.zergpool.com:8080/api/wallet?address=$($Config.Wallet.BTC)"
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
		Profit = [decimal]$RequestCurrency.$_.estimate
	}
}

$RequestStatus | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
	$Pool_Algorithm = Get-Algo($RequestStatus.$_.name)
	if ($Pool_Algorithm) {
		$Pool_Host = if ($Config.Region -eq [eRegion]::Europe) { "europe.mine.zergpool.com" } else { "mine.zergpool.com" }
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
		$CurrencyFiltered | ForEach-Object {
			$prof = $_.Profit / 1000
			# next three lines try to fix error in output profit
			if ($prof -gt $Algo.estimate_last24h * 2) { $prof = $Algo.estimate_last24h }
			if ($Algo.actual_last24h -gt $Algo.estimate_last24h * 2) { $Algo.actual_last24h = $Algo.estimate_last24h }
			if ($Algo.actual_last24h -gt 0 -and $Algo.estimate_last24h -gt $Algo.actual_last24h * 2) { $Algo.estimate_last24h = $Algo.actual_last24h }

			if ($Algo.actual_last24h -gt 0.0) {
				$Profit = $prof * 0.10 + $Algo.estimate_last24h * 0.20 + $Algo.actual_last24h * 0.70
			}
			else {
				$Profit = $prof * 0.15 + $Algo.estimate_last24h * 0.85
			}

			$Profit *= (1 - [decimal]$Algo.fees / 100) * $Variety / $Divisor
				
			if ($MaxCoin -eq $null -or $_.Profit -gt $MaxCoin.Profit) {
				$MaxCoin = $_
				$MaxCoinProfit = $Profit
			}

			if ($AuxCoins.Contains($_.Coin)) {
				$AuxProfit += $prof * (1 - [decimal]$Algo.fees / 100) * $Variety / $Divisor
			}
		}

		if ($MaxCoinProfit -gt 0) {
			$MaxCoinProfit = Set-Stat -Filename ($PoolInfo.Name) -Key $Pool_Algorithm -Value ($MaxCoinProfit + $AuxProfit) -Interval $Cfg.AverageProfit

			$PoolInfo.Algorithms.Add([PoolAlgorithmInfo] @{
				Name = $PoolInfo.Name
				Algorithm = $Pool_Algorithm
				Profit = ($MaxCoinProfit + $AuxProfit)
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
