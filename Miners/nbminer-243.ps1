<#
MindMiner  Copyright (C) 2019  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $true
	BenchmarkSeconds = 120
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cuckaroo" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cuckarood" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cuckaroo_swap" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cuckatoo" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cuckoo_ae" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "ethash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "progpow_sero" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sipc" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "tensority" }
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
				$fee = 2
				switch ($_.Algorithm) {
					"ethash" { $fee = 0.65 }
					"tensority" { $fee = 3 }
					default {}
				}
				$stratum = $Pool.Protocol
				$port = $Pool.Port
				if ($Pool.Name -match "nicehash") { $stratum = "nicehash+tcp" }
				elseif ($_.Algorithm -match "ethash") {
					$stratum = "ethproxy+tcp"
					$port = $Pool.PortUnsecure
				}
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "nbminer"
					URI = "https://github.com/NebuTech/NBMiner/releases/download/v24.3/NBMiner_24.3_Win.zip"
					Path = "$Name\nbminer.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) -o $stratum`://$($Pool.Host):$port -u $($Pool.User):$($Pool.Password) --api 127.0.0.1:4068 --no-nvml -no-watchdog $extrargs"
					Port = 4068
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = $fee
				}
			}
		}
	}
}