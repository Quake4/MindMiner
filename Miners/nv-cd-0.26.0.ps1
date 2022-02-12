<#
MindMiner  Copyright (C) 2018-2022  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if (![Config]::Is64Bit) { exit }
if ([Config]::CudaVersion -lt [version]::new(11, 2)) { return }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 180
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2d-dyn" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2d-nim" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2d250" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2d4096" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2d4096"; ExtraArgs = "-i 7" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2d4096"; ExtraArgs = "-i 8" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "chukwa" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "chukwa2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cnconceal" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cnfast2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cngpu" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cnhaven" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cnheavy" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cntlo" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cnturtle" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cnupx2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cnzls" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "kawpow" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "mtp" } # unstable
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "mtp-tcr" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "ninja" }
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
					URI = "https://mindminer.online/miners/nVidia/cryptodredge-0.16.0-11.2.zip"
					Path = "$Name\cryptodredge.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) -o stratum+tcp://$($Pool.Hosts[0]):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -R $($Config.CheckTimeout) -b 127.0.0.1:4068 --api-type ccminer-tcp --no-watchdog $N $extrargs"
					Port = 4068
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = if ($_.Algorithm -match "mtp") { 2 } else { 1 }
				}
			}
		}
	}
}