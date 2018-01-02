<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Include.ps1

$PoolInfo = [PoolInfo]::new()
$PoolInfo.Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

if ([string]::IsNullOrWhiteSpace($Config.Login)) { return $PoolInfo }

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $PoolInfo.Name + [BaseConfig]::Filename), @{
	Enabled = $true
	AverageProfit = "1 hour 30 min"
	ApiKey = ""
})
$PoolInfo.Enabled = $Cfg.Enabled
$PoolInfo.AverageProfit = $Cfg.AverageProfit

if (!$Cfg.Enabled) { return $PoolInfo }
$Pool_Variety = 0.85

try {
	$Request = Get-UrlAsJson "http://miningpoolhub.com/index.php?page=api&action=getminingandprofitsstatistics"
}
catch { return $PoolInfo }

try {
	if (![string]::IsNullOrWhiteSpace($Cfg.ApiKey)) {
		$RequestBalance = Get-UrlAsJson "https://miningpoolhub.com/index.php?page=api&action=getuserallbalances&api_key=$($Cfg.ApiKey)"
	}
}
catch { }

if (!$Request -or !($Request.success -eq $true)) { return $PoolInfo }
$PoolInfo.HasAnswer = $true
$PoolInfo.AnswerTime = [DateTime]::Now

if ($RequestBalance) {
	$RequestBalance.getuserallbalances.data | ForEach-Object {
		if ($_.coin -eq "bitcoin") {
			$PoolInfo.Balance.Value = [decimal]$_.confirmed
			$PoolInfo.Balance.Additional = [decimal]$_.unconfirmed
		}
	}
}

if ($Config.SSL -eq $true) { $Pool_Protocol = "stratum+ssl" } else { $Pool_Protocol = "stratum+tcp" }
$Pool_Regions = "europe", "us", "asia"

$Pool_Regions | ForEach-Object {
	$Pool_Region = $_
	[eRegion]$Miner_Region = [eRegion]::Other

	switch ($Pool_Region) {
		"europe" { $Miner_Region = [eRegion]::Europe }
		"us" { $Miner_Region = [eRegion]::Usa }
		"asia" { $Miner_Region = [eRegion]::China }
	}

	if ($Config.Region -eq $Miner_Region) {
		$Request.return | ForEach-Object {
			$Pool_Algorithm = Get-Algo($_.algo)
			if ($Pool_Algorithm) {
				$Pool_Host = $_.host_list.split(";") | Where-Object { $_.Contains($Pool_Region) } | Select-Object -First 1
				$Pool_Port = $_.port
				$Coin = (Get-Culture).TextInfo.ToTitleCase($_.coin_name)
				if (!$Coin.StartsWith($_.algo)) {
					$Coin = $Coin.Replace($_.algo, "")
				}
				$Coin = $Coin.Replace("-", "").Replace("DigibyteGroestl", "Digibyte").Replace("MyriadcoinGroestl", "MyriadCoin")

				$Divisor = 1000000000
				$Profit = [decimal]$_.profit * (1 - 0.009) * $Pool_Variety / $Divisor

				if ($Profit -gt 0) {
					$Profit = Set-Stat -Filename ($PoolInfo.Name) -Key "$Pool_Algorithm`_$Coin" -Value $Profit -Interval $Cfg.AverageProfit

					$PoolInfo.Algorithms.Add([PoolAlgorithmInfo] @{
						Name = $PoolInfo.Name
						Algorithm = $Pool_Algorithm
						Info = "$Miner_Region-$Coin"
						InfoAsKey = $true
						Profit = $Profit
						Protocol = $Pool_Protocol
						Host = $Pool_Host
						Port = $Pool_Port
						PortUnsecure = $Pool_Port
						User = "$($Config.Login).$($Config.WorkerName)"
						Password = $Config.Password
						ByLogin = $true
					})
				}
			}
		}
	}
}

$PoolInfo