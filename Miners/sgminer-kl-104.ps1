<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $true
	BenchmarkSeconds = 120
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "phi"; BenchmarkSeconds = 180; ExtraArgs="-X 256 -g 2 -w 256" } # with build
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "tribus"; BenchmarkSeconds = 180; ExtraArgs="-X 256 -g 2" } # with build
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x16r"; BenchmarkSeconds = 180; ExtraArgs="-X 256 -g 2" } # with build
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x16s"; ExtraArgs="-X 256 -g 2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x17"; ExtraArgs="-X 256 -g 2" } # with build
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "xevan"; ExtraArgs="-X 256 -g 2" } # with build
)})

if (!$Cfg.Enabled) { return }

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
					Type = [eMinerType]::AMD
					API = "sgminer"
					URI = "https://github.com/KL0nLutiy/sgminer-kl/releases/download/kl-1.0.4/sgminer-kl-1.0.4-windows.zip"
					Path = "$Name\sgminer.exe"
					ExtraArgs = $extrargs
					Arguments = "-k $($_.Algorithm) -o stratum+tcp://$($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) --api-listen --gpu-platform $([Config]::AMDPlatformId) $extrargs"
					Port = 4028
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = 1
				}
			}
		}
	}
}