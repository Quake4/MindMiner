<#
MindMiner  Copyright (C) 2018-2020  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia -and [Config]::ActiveTypes -notcontains [eMinerType]::AMD) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $true
	BenchmarkSeconds = 120
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "aeternity" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "aion" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "beam" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "beamv2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "beamv3" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cuckatoo31" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cuckatoo32" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cuckarood29" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cuckaroom29" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash125" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash144" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash192" }
		# [AlgoInfoEx]@{ Enabled = $([Config]::ActiveTypes -notcontains [eMinerType]::nVidia); Algorithm = "equihash96" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihashBTG" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihashZCL" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "etchash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "ethash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "zhash" }
)})

if (!$Cfg.Enabled) { return }

$url = "https://github.com/Lolliedieb/lolMiner-releases/releases/download/1.17/lolMiner_v1.17_Win64.zip"

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				$coin = [string]::Empty
				$fee = 1
				if ($extrargs -notmatch "--coin" -and $extrargs -notmatch "--algo") {
					switch ($_.Algorithm) {
						"aeternity" { $coin = "--algo C29AE" }
						"aion" { $coin = "--coin AION" }
						"beam" { $coin = "--algo BEAM-I" }
						"beamv2" { $coin = "--algo BEAM-II" }
						"beamv3" { $coin = "--algo BEAM-III" }
						"cuckatoo31" { $coin = "--algo C31"; $fee = 2 }
						"cuckatoo32" { $coin = "--algo C32"; $fee = 2 }
						"cuckarood29" { $coin = "--algo C29D"; $fee = 2 }
						"cuckaroom29" { $coin = "--coin GRIN-C29M"; $fee = 2 }
						"zhash" { $coin = "--coin AUTO144_5" }
						"equihash125" { $coin = "--coin ZEL" }
						"equihash144" { $coin = "--coin AUTO144_5" }
						"equihash192" { $coin = "--coin AUTO192_7" }
						# "equihash96" { $coin = "--coin MNX" }
						"equihashBTG" { $coin = "--coin BTG" }
						"equihashZCL" { $coin = "--algo EQUI192_7 --pers ZcashPoW" }
						"etchash" { $coin = "--algo ETCHASH" }
						"ethash" { $coin = "--algo ETHASH" }
					}
				}
				$pools = [string]::Empty
				$Pool.Hosts | ForEach-Object {
					$pools = Get-Join " " @($pools, "--pool $_`:$($Pool.PortUnsecure) --user $($Pool.User) --pass $($Pool.Password) --tls 0")
				}
				if ($_.Algorithm -eq "ethash" -or $_.Algorithm -eq "etchash") {
					$pools += " --worker $([Config]::WorkerNamePlaceholder)"
					if ($Pool.Name -match "mph" -or $Pool.Name -match "nicehash") {
						$pools += " --ethstratum ETHV1"
					}
				}
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Priority = $Pool.Priority
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					TypeInKey = $true
					API = "lolnew"
					URI = $url
					Path = "$Name\lolMiner.exe"
					ExtraArgs = $extrargs
					Arguments = "$coin $pools --apiport 4068 --timeprint 1 --devices NVIDIA $extrargs"
					Port = 4068
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = $fee
				}
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Priority = $Pool.Priority
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::AMD
					TypeInKey = $true
					API = "lolnew"
					URI = $url
					Path = "$Name\lolMiner.exe"
					ExtraArgs = $extrargs
					Arguments = "$coin $pools --apiport 4028 --timeprint 1 --devices AMD $extrargs"
					Port = 4028
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = $fee
				}
			}
		}
	}
}