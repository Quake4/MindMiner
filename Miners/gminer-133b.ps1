<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
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
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "aeternity" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "beam" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash144" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash192" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash96" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "grin29" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "grin31" }
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
				$type = if ([Config]::ActiveTypes -contains [eMinerType]::nVidia) { [eMinerType]::nVidia } else { $null }
				if ($_.Algorithm -match "aeternity") {
					$alg = "-a aeternity"
				}
				elseif ($_.Algorithm -match "beam") {
					$alg = "-a 150_5"
					if ([Config]::ActiveTypes -contains [eMinerType]::nVidia -and [Config]::ActiveTypes -contains [eMinerType]::AMD) {
						$type = $null
					}
					elseif ([Config]::ActiveTypes -contains [eMinerType]::AMD) {
						$type = [eMinerType]::AMD
					}
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
				elseif ($_.Algorithm -match "grin29") {
					$alg = "-a grin29"
				}
				elseif ($_.Algorithm -match "grin31") {
					$alg = "-a grin31"
				}
				if ($type) {
					$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
					[MinerInfo]@{
						Pool = $Pool.PoolName()
						PoolKey = $Pool.PoolKey()
						Name = $Name
						Algorithm = $Algo
						Type = $type
						API = "gminer"
						URI = "https://github.com/develsoftware/GMinerBetaRelease/releases/download/1.33/gminer_1_33_minimal_windows64.zip"
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
}
