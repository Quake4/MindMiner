<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if (![Config]::Is64Bit) { exit }
if ([Config]::CudaVersion -lt [version]::new(10, 0)) { return }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 120
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2d-dyn" }
)}

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$BenchSecs = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
				$N = "-N $([Convert]::ToInt32($BenchSecs/2))"
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "ccminer"
					URI = "https://github.com/duality-solutions/Dynamic-GPU-Miner-Nvidia/releases/download/v1.0.0/ccminer-dyn-1.0.0.rar"
					Path = "$Name\ccminer.exe"
					ExtraArgs = $extrargs
					Arguments = "-a argon2d -o stratum+tcp://$($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -R $($Config.CheckTimeout) -T 60 -b 127.0.0.1:4068 $N $extrargs"
					Port = 4068
					BenchmarkSeconds = $BenchSecs
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = 1
				}
			}
		}
	}
}