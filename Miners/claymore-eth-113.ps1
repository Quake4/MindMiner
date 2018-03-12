<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Include.ps1

if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $true
	BenchmarkSeconds = 90
	Algorithms = @(
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "ethash" }
#	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash"; ExtraArgs = "" }
)})

if (!$Cfg.Enabled) { return }

$file = [IO.Path]::Combine($BinLocation, $Name, "epools.txt")
if ([IO.File]::Exists($file)) {
	[IO.File]::Delete($file)
}

$file = [IO.Path]::Combine($BinLocation, $Name, "dpools.txt")
if ([IO.File]::Exists($file)) {
	[IO.File]::Delete($file)
}

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$esm = 2 # MiningPoolHub
				if ($Pool.Name -contains "nicehash") {
					$esm = 3
				}
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::AMD
					API = "claymore"
					URI = "https://github.com/Quake4/MindMinerPrerequisites/raw/master/AMD/Claymore/Claymore-Dual-Ethereum-AMD+NVIDIA-Miner-v11.3.zip"
					Path = "$Name\EthDcrMiner64.exe"
					ExtraArgs = "$($_.ExtraArgs)"
					Arguments = "-epool $($Pool.Host):$($Pool.PortUnsecure) -ewal $($Pool.User) -epsw $($Pool.Password) -retrydelay 5 -mode 1 -allpools 1 -esm $esm -mport -3350 -platform 1 $($_.ExtraArgs)"
					Port = 3350
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					Fee = 1
				}
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "claymore"
					URI = "https://github.com/Quake4/MindMinerPrerequisites/raw/master/AMD/Claymore/Claymore-Dual-Ethereum-AMD+NVIDIA-Miner-v11.3.zip"
					Path = "$Name\EthDcrMiner64.exe"
					ExtraArgs = "$($_.ExtraArgs)"
					Arguments = "-epool $($Pool.Host):$($Pool.PortUnsecure) -ewal $($Pool.User) -epsw $($Pool.Password) -retrydelay 5 -mode 1 -allpools 1 -esm $esm -mport -3360 -platform 2 $($_.ExtraArgs)"
					Port = 3360
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					Fee = 1
				}
			}
		}
	}
}