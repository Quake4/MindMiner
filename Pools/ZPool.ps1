<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Include.ps1

if (!$Config.Wallet.BTC) { return }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $true
	AverageProfit = "1 hour 30 min"
})

if (!$Cfg.Enabled) { return }

$Pool_Variety = 0.80
# zpool already accounting Aux's
$AuxCoins = @(<#"UIS", "MBL"#>)

try {
	$RequestStatus = Get-UrlAsJson "https://www.zpool.ca/api/status"
}
catch { return }

try {
	$RequestCurrency = Get-UrlAsJson "https://www.zpool.ca/api/currencies"
}
catch { return }

if (!$RequestStatus -or !$RequestCurrency) { return }

# if ($Config.SSL -eq $true) { $Pool_Protocol = "stratum+ssl" } else { $Pool_Protocol = "stratum+tcp" }

$Currency = $RequestCurrency | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
	[PSCustomObject]@{
		Coin = if (!$RequestCurrency.$_.symbol) { $_ } else { $RequestCurrency.$_.symbol }
		Algo = $RequestCurrency.$_.algo
		Profit = $RequestCurrency.$_.estimate
	}
}

$RequestStatus | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
	$Pool_Algorithm = Get-Algo($RequestStatus.$_.name)
	if ($Pool_Algorithm) {
		$Pool_Host = "$($RequestStatus.$_.name).mine.zpool.ca"
		$Pool_Port = $RequestStatus.$_.port

		$Divisor = 1000000
		
		switch ($Pool_Algorithm) {
			"blake" { $Divisor *= 1000 }
			"blake2s" { $Divisor *= 1000 }
			"blakecoin" { $Divisor *= 1000 }
			"decred" { $Divisor *= 1000 }
			"equihash" { $Divisor /= 1000 }
			"keccak" { $Divisor *= 1000 }
			"nist5" { $Divisor *= 3 }
			"qubit" { $Divisor *= 1000 }
			"x11" { $Divisor *= 1000 }
			"yescrypt" { $Divisor /= 1000 }
		}

		# find more profit coin in algo
		$Algo = $RequestStatus.$_
		$MaxCoin = $null;
		$MaxCoinProfit = $null
		[decimal]$AuxProfit = 0
		# convert to one dimension and decimal
		$Algo.actual_last24h = [decimal]$Algo.actual_last24h / 1000
		$Algo.estimate_last24h = [decimal]$Algo.estimate_last24h
		$Currency | Where-Object { $_.Algo -eq $Algo.name } | ForEach-Object {
			$prof = [decimal]$_.Profit / 1000
			# next three lines try to fix zpool error in output profit
			if ($prof -gt $Algo.estimate_last24h * 2) { $prof = $Algo.estimate_last24h }
			if ($Algo.actual_last24h -gt $Algo.estimate_last24h * 2) { $Algo.actual_last24h = 0 }
			if ($Algo.estimate_last24h -gt $Algo.actual_last24h * 2) { $Algo.estimate_last24h = $Algo.actual_last24h }

			if ($Algo.actual_last24h -gt 0.0) {
				$Profit = $prof * 0.05 + $Algo.estimate_last24h * 0.35 + $Algo.actual_last24h * 0.60
			}
			else {
				$Profit = $prof * 0.15 + $Algo.estimate_last24h * 0.85
			}

			$Profit *= (1 - [decimal]$Algo.fees / 100) * $Pool_Variety / $Divisor
				
			if ($MaxCoin -eq $null -or $_.Profit -gt $MaxCoin.Profit) {
				$MaxCoin = $_
				$MaxCoinProfit = $Profit
			}

			if ($AuxCoins.Contains($_.Coin)) {
				$AuxProfit += $prof * (1 - [decimal]$Algo.fees / 100) * $Pool_Variety / $Divisor
			}
		}

		if ($MaxCoinProfit -gt 0) {
			$MaxCoinProfit = Set-Stat -Filename $Name -Key $Pool_Algorithm -Value ($MaxCoinProfit + $AuxProfit) -Interval $Cfg.AverageProfit

			[PoolInfo] @{
				Name = $Name
				Algorithm = $Pool_Algorithm
				Profit = ($MaxCoinProfit + $AuxProfit)
				Info = $MaxCoin.Coin
				#StablePrice = $null
				#PriceFluctuation = $null
				Protocol = "stratum+tcp" # $Pool_Protocol
				Host = $Pool_Host
				Port = $Pool_Port
				User = $Config.Wallet.BTC
				Password = "c=BTC,$($Config.WorkerName)" # "c=$($MaxCoin.Coin),$($Config.WorkerName)";
				ByLogin = $false
			}
		}
	}
}