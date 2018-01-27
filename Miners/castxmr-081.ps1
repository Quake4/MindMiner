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
	BenchmarkSeconds = 60
	Algorithms = @(
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonight" }
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonight"; ExtraArgs = "--forcecompute"; BenchmarkSeconds = 90 }
)})

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::AMD
					API = "cast"
					URI = "http://www.gandalph3000.com/download/cast_xmr-vega-win64_081.zip"
					Path = "$Name\cast_xmr-vega.exe"
					ExtraArgs = "$($_.ExtraArgs)"
					Arguments = "-S $($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -R --fastjobswitch $($_.ExtraArgs)"
					Port = 7777
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					Fee = 1.5
				}
			}
		}
	}
}