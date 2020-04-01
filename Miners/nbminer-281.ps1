<#
MindMiner  Copyright (C) 2019-2020  Oleg Samsonov aka Quake4
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
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "bfc" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cuckaroo" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cuckarood" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cuckaroo_swap" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cuckatoo" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cuckoo_ae" }
		# [AlgoInfoEx]@{ Enabled = $true; Algorithm = "ethash" } # not compatible with mph and mrr
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "eaglesong" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "hns" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "progpow_sero" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sipc" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "tensority" }
)})

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo -and $_.Algorithm -notmatch "ethash") {
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
				$pools = [string]::Empty
				for ($i = 0; $i -lt $Pool.Hosts.Count -and $i -lt 3; $i++) {
					$idx = if ($i -eq 0) { [string]::Empty } else { $i.ToString() }
					$pools = Get-Join " " @($pools, "-o$idx $stratum`://$($Pool.Hosts[$i]):$port -u$idx $($Pool.User):$($Pool.Password)")
				}
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Priority = $Pool.Priority
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "nbminer"
					URI = "https://github.com/NebuTech/NBMiner/releases/download/v28.1/NBMiner_28.1_Win.zip"
					Path = "$Name\nbminer.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) $pools --api 127.0.0.1:4068 --no-nvml -no-watchdog --platform 1 $extrargs"
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
