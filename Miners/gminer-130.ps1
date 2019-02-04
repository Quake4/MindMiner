<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 90
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "aeternity" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "beam" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash144" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash192" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash96" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "grin" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "zhash" }
)}

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$alg = [string]::Empty
				if ($_.Algorithm -match "aeternity") {
					$alg = "-a aeternity"
				}
				elseif ($_.Algorithm -match "beam") {
					$alg = "-a 150_5"
				}
				elseif ($_.Algorithm -match "zhash" -or $_.Algorithm -match "equihash144") {
					$alg = "-a 144_5 --pers auto"
				}
				elseif ($_.Algorithm -match "equihash192") {
					$alg = "-a 192_7 --pers auto"
				}
				elseif ($_.Algorithm -match "equihash96") {
					$alg = "-a 96_5 --pers auto"
				}
				elseif ($_.Algorithm -match "grin") {
					$alg = "-a grin29"
				}
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "gminer"
					URI = "http://mindminer.online/miners/nVidia/gminer-130.zip"
					Path = "$Name\miner.exe"
					ExtraArgs = $extrargs
					Arguments = "$alg -s $($Pool.Host) -n $($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) --api 42000 --pec 0 -w 0 $extrargs"
					Port = 42000
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = 2
				}
			}
		}
	}
}