<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4/Quake3
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Include.ps1

if ([string]::IsNullOrWhiteSpace($Config.Login)) { return }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $true
	AverageProfit = "1 hour 30 min"
})

if (!$Cfg.Enabled) { return }
$Pool_Variety = 0.85

try {
	$Request = Get-UrlAsJson "http://miningpoolhub.com/index.php?page=api&action=getminingandprofitsstatistics"
}
catch {
	return
}

if (!$Request -or !($Request.success -eq $true)) { return }

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
					$Profit = Set-Stat -Filename $Name -Key "$Pool_Algorithm`_$Coin" -Value $Profit -Interval $Cfg.AverageProfit

					[PoolInfo] @{
						Name = $Name
						Algorithm = $Pool_Algorithm
						Info = "$Miner_Region-$Coin"
						Profit = $Profit
						Protocol = $Pool_Protocol
						Host = $Pool_Host
						Port = $Pool_Port
						User = "$($Config.Login).$($Config.WorkerName)"
						Password = $Config.Password
					}
				}
			}
		}
	}
}