<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::AMD) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $true
	BenchmarkSeconds = 120
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "aergo"; BenchmarkSeconds = 180 } # with build
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "geek" } # with build
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "phi"; BenchmarkSeconds = 180 } # with build
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "polytimos"; BenchmarkSeconds = 180 } # with build
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "tribus" } # with build
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x16r"; BenchmarkSeconds = 180 } # with build
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x16s"; BenchmarkSeconds = 90 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x17" } # with build
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "xevan" } # with build
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
				$add = [string]::Empty
				if ($extrargs -notmatch "-X ") {
					$add = Get-Join " " @($add, "-X 256")
				}
				if ($extrargs -notmatch "-g ") {
					$add = Get-Join " " @($add, "-g 2")
				}
				if ($extrargs -notmatch "-w " -and ($_.Algorithm -eq "phi" -or $_.Algorithm -eq "polytimos")) {
					$add = Get-Join " " @($add, "-w 256")
				}
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::AMD
					API = "sgminer"
					URI = "https://github.com/KL0nLutiy/sgminer-kl/releases/download/kl-1.0.7/sgminer-kl-1.0.7-windows.zip"
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