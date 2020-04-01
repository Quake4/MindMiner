<#
MindMiner  Copyright (C) 2020  Oleg Samsonov aka Quake4
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
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "bl2bsha3" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "blake2b" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "blake2s" } # only dual
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonight_bbc" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonight_catalans" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonight_talleo" }
		# [AlgoInfoEx]@{ Enabled = $false; Algorithm = "eaglesong" } # share above target on nice
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "k12" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "kadena" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "keccak" } # only dual
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "mtp" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "rainforestv2" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "yescrypt" } # too slow
)}

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				$nicehash = "--nicehash false"
				if ($Pool.Name -match "nicehash") {
					$nicehash = "--nicehash true"
				}
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Priority = $Pool.Priority
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::AMD
					API = "srbm"
					URI = "https://github.com/doktor83/SRBMiner-Multi/releases/download/0.4.1/SRBMiner-Multi-0-4-1-win64.zip"
					Path = "$Name\SRBMiner-MULTI.exe"
					ExtraArgs = $extrargs
					Arguments = "--algorithm $($_.Algorithm) --pool $($Pool.Hosts[0]):$($Pool.PortUnsecure) --wallet $($Pool.User) --password $($Pool.Password) --tls false --api-enable --api-port 4044 --disable-cpu --disable-gpu-watchdog --retry-time $($Config.CheckTimeout) $nicehash $extrargs"
					Port = 4044
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = 0.85
				}
			}
		}
	}
}
