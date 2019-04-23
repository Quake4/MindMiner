<#
MindMiner  Copyright (C) 2018 - 2019  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia -and [Config]::ActiveTypes -notcontains [eMinerType]::AMD) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 90
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2ad" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2d250" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "argon2d500"; ExtraArgs = "--gpu-batchsize=512 -t 1" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "argon2d500"; ExtraArgs = "--gpu-batchsize=1024 -t 1" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "argon2d500"; ExtraArgs = "--gpu-batchsize=2048 -t 1" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "argon2d500"; ExtraArgs = "--gpu-batchsize=4096 -t 1" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2d4096"; ExtraArgs = "--gpu-batchsize=128 -t 1" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2d4096"; ExtraArgs = "--gpu-batchsize=128 -t 2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2d4096"; ExtraArgs = "--gpu-batchsize=256 -t 1" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2d4096"; ExtraArgs = "--gpu-batchsize=256 -t 2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2d4096"; ExtraArgs = "--gpu-batchsize=512 -t 1" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2d4096"; ExtraArgs = "--gpu-batchsize=512 -t 2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2d4096"; ExtraArgs = "--gpu-batchsize=1024 -t 1" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2d4096"; ExtraArgs = "--gpu-batchsize=1024 -t 2" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "argon2d4096"; ExtraArgs = "--gpu-batchsize=2048 -t 1" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "argon2d4096"; ExtraArgs = "--gpu-batchsize=2048 -t 2" }
)}

if (!$Cfg.Enabled) { return }

$url = "https://github.com/bogdanadnan/multiminer/releases/download/v1.1.0/multiminer_v1.1.0_24.01.2019.zip"

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "ccminer"
					URI = $url
					Path = "$Name\multiminer.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) -o stratum+tcp://$($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -R $($Config.CheckTimeout) -T 60 -b 127.0.0.1:4068 -q --use-gpu=CUDA $extrargs"
					Port = 4068
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = 1
				}
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::AMD
					API = "ccminer"
					URI = $url
					Path = "$Name\multiminer.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) -o stratum+tcp://$($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -R $($Config.CheckTimeout) -T 60 -b 127.0.0.1:4068 -q --use-gpu=OPENCL $extrargs"
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