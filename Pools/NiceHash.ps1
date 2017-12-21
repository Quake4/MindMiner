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
	AverageProfit = "20 min"
})

if (!$Cfg.Enabled) { return }

try {
	$Request = Get-UrlAsJson "https://api.nicehash.com/api?method=simplemultialgo.info"
}
catch {
	return
}

if (!$Request) { return }

if ($Config.SSL -eq $true) { $Pool_Protocol = "stratum+ssl" } else { $Pool_Protocol = "stratum+tcp" }
$Pool_Regions = "eu", "usa", "hk", "jp", "in", "br"

$Pool_Regions | ForEach-Object {
	$Pool_Region = $_
	[eRegion]$Miner_Region = [eRegion]::Other

	switch ($Pool_Region) {
		"eu" { $Miner_Region = [eRegion]::Europe }
		"usa" { $Miner_Region = [eRegion]::Usa }
		"hk" { $Miner_Region = [eRegion]::China }
		"jp" { $Miner_Region = [eRegion]::Japan }
	}

	if ($Config.Region -eq $Miner_Region) {
		$Request.result.simplemultialgo | ForEach-Object {
			$Pool_Algorithm = Get-Algo($_.name)
			if ($Pool_Algorithm) {
				$Pool_Host = "$($_.name).$Pool_Region.nicehash.com"
				$Pool_Port = $_.port

				$Divisor = 1000000000
				$Profit = [Double]$_.paying * (1 - 0.04) / $Divisor

				if ($Profit -gt 0) {
					$Profit = Set-Stat -Filename $Name -Key $Pool_Algorithm -Value $Profit -Interval $Cfg.AverageProfit

					[PoolInfo] @{
						Name = $Name
						Algorithm = $Pool_Algorithm
						Info = $Miner_Region
						Profit = $Profit
						Protocol = $Pool_Protocol
						Host = $Pool_Host
						Port = $Pool_Port
						User = "$($Config.Wallet.BTC).$($Config.WorkerName)"
						Password = $Config.Password
						ByLogin = $false
					}
				}
			}
		}
	}
}
