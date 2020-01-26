<#
MindMiner  Copyright (C) 2017-2020  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if (![Config]::Is64Bit) { exit }
if ([Config]::CudaVersion -lt [version]::new(9, 0)) { return }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 120
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sha3d" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sha3d"; ExtraArgs = "-i 24" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sha3d"; ExtraArgs = "-i 25" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sha3d"; ExtraArgs = "-i 26" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sha3d"; ExtraArgs = "-i 27" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sha3d"; ExtraArgs = "-i 28" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sha3d"; ExtraArgs = "-i 29" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sha3d"; ExtraArgs = "-i 30" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sha3d"; ExtraArgs = "-i 31" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sha3d"; ExtraArgs = "-i 31.999999" }
)}

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$N = Get-CCMinerStatsAvg $Algo $_
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Priority = $Pool.Priority
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "ccminer"
					URI = "https://github.com/brian112358/ccminer-bsha3/releases/download/v1.0/ccminer-bsha3-v1.0-win64.zip"
					Path = "$Name\ccminer.exe"
					ExtraArgs = $extrargs
					Arguments = "-a keccak -o stratum+tcp://$($Pool.Hosts[0]):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -R $($Config.CheckTimeout) $N $extrargs"
					Port = 4068
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = 1
				}
			}
		}
	}
}
