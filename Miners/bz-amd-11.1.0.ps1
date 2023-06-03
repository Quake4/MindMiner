<#
MindMiner  Copyright (C) 2017-2022  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::AMD) { exit }
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
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "ixi" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "kaspa" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "neox" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "olhash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "rvn" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "woodcoin" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "zil" }
)}

if (!$Cfg.Enabled) { return }

$port = [Config]::Ports[[int][eMinerType]::AMD]

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				$fee = 0.5
				if (("olhash", "kaspa", "ixi") -contains $_.Algorithm) { $fee = 1 }
				elseif ($_.Algorithm -match "zil") { $fee = 0 }
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Priority = $Pool.Priority
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::AMD
					API = "bzminer"
					URI = "https://www.bzminer.com/downloads/bzminer_v11.1.0_windows.zip"
					Path = "$Name\bzminer.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) -p $($Pool.Hosts[0]):$($Pool.PortUnsecure) -w $($Pool.User) --pool_password $($Pool.Password) --no_watchdog --nvidia 0 --amd 1 --nc 1 --update_frequency_ms 60000 --http_address 127.0.0.1 --http_port $port $extrargs"
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