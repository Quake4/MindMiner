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
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "swap" }
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
				$alg = "-a $($_.Algorithm)"
				$types = if ([Config]::ActiveTypes -contains [eMinerType]::nVidia) { [eMinerType]::nVidia } else { $null }
				if ($_.Algorithm -match "aeternity" -or $_.Algorithm -match "beam" -or $_.Algorithm -match "swap") {
					if ([Config]::ActiveTypes -contains [eMinerType]::nVidia -and [Config]::ActiveTypes -contains [eMinerType]::AMD) {
						$types = @([eMinerType]::nVidia, [eMinerType]::AMD)
					}
					elseif ([Config]::ActiveTypes -contains [eMinerType]::AMD) {
						$types = [eMinerType]::AMD
					}
				}
				if ($_.Algorithm -match "beam") {
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
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				$benchsecs = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
				$runbefore = $_.RunBefore
				$runafter = $_.RunAfter
				$types | ForEach-Object {
					if ($_) {
						$devs = if ($_ -eq [eMinerType]::nVidia) { "--cuda 1 --opencl 0" } else { "--cuda 0 --opencl 1" }
						$port = if ($_ -eq [eMinerType]::nVidia) { 42000 } else { 42001 }
						[MinerInfo]@{
							Pool = $Pool.PoolName()
							PoolKey = $Pool.PoolKey()
							Name = $Name
							Algorithm = $Algo
							Type = $_
							TypeInKey =  if ($_ -eq [eMinerType]::AMD) { $true } else { $false }
							API = "gminer"
							URI = "https://github.com/develsoftware/GMinerRelease/releases/download/1.36/gminer_1_36_minimal_windows64.zip"
							Path = "$Name\miner.exe"
							ExtraArgs = $extrargs
							Arguments = "$alg -s $($Pool.Host) -n $($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) --api $port --pec 0 -w 0 $devs $extrargs"
							Port = $port
							BenchmarkSeconds = $benchsecs
							RunBefore = $runbefore
							RunAfter = $runafter
							Fee = 2
						}
					}
				}
			}
		}
	}
}