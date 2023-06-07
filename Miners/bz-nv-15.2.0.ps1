<#
MindMiner  Copyright (C) 2017-2023  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 90
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "alph" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "ergo" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "etchash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "ethash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "ironfish" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "ixi" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "kaspa" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "kylacoin" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "meowcoin" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "neox" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "nexa" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "novo" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "octa" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "olhash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "radiant" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "rvn" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "woodcoin" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "zil" }
)}

if (!$Cfg.Enabled) { return }

$port = [Config]::Ports[[int][eMinerType]::nVidia]

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				$fee = 0.5
				if (("olhash", "kaspa", "kylacoin", "ironfish", "ixi", "radiant", "woodcoin") -contains $_.Algorithm) { $fee = 1 }
				if ($_.Algorithm -match "nexa") { $fee = 20 } # fix fake hashrate
				elseif ($_.Algorithm -match "zil") { $fee = 0 }
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Priority = $Pool.Priority
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "bzminer"
					URI = "https://www.bzminer.com/downloads/bzminer_v15.2.0_windows.zip"
					Path = "$Name\bzminer.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) -p $($Pool.Hosts[0]):$($Pool.PortUnsecure) -w $($Pool.User) --pool_password $($Pool.Password) --no_watchdog --nvidia 1 --amd 0 --nc 1 --update_frequency_ms 60000 --http_address 127.0.0.1 --http_port $port $extrargs"
					Port = $port
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = $fee
				}
			}
		}
	}
}