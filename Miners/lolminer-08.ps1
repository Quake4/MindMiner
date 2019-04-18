<#
MindMiner  Copyright (C) 2018 - 2019  Oleg Samsonov aka Quake4
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
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "beam" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash144" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash192" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash96" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihashBTG" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "zhash" }
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
				$coin = [string]::Empty
				$fee = 1
				if ($extrargs -notmatch "--coin ") {
					switch ($_.Algorithm) {
						"beam" { $coin = "--coin BEAM" }
						"zhash" { $coin = "--coin AUTO144_5" }
						"equihash144" { $coin = "--coin AUTO144_5" }
						"equihash192" { $coin = "--coin AUTO192_7" }
						"equihash96" { $coin = "--coin MNX" }
						"equihashBTG" { $coin = "--coin BTG" }
					}
				}
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					TypeInKey = $true
					API = "lolnew"
					URI = "https://github.com/Lolliedieb/lolMiner-releases/releases/download/0.8/lolMiner_v08_Win64.zip"
					Path = "$Name\lolMiner.exe"
					ExtraArgs = $extrargs
					Arguments = "$coin --pool $($Pool.Host) --port $($Pool.PortUnsecure) --user $($Pool.User) --pass $($Pool.Password) --apiport 4068 --timeprint 1 --disable_memcheck 1 --devices NVIDIA --tls 0 $extrargs"
					Port = 4068
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = $fee
				}
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::AMD
					TypeInKey = $true
					API = "lolnew"
					URI = "https://github.com/Lolliedieb/lolMiner-releases/releases/download/0.8/lolMiner_v08_Win64.zip"
					Path = "$Name\lolMiner.exe"
					ExtraArgs = $extrargs
					Arguments = "$coin --pool $($Pool.Host) --port $($Pool.PortUnsecure) --user $($Pool.User) --pass $($Pool.Password) --apiport 4028 --timeprint 1 --disable_memcheck 1 --devices AMD --tls 0 $extrargs"
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