<#
MindMiner  Copyright (C) 2018-2019  Oleg Samsonov aka Quake4
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
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "beamhash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "beamhashII" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "bfc" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cuckaroo29" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cuckarood29" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash125_4" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash144_5" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash192_7" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash96_5" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "grimm" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "grin31" } # all faster
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "swap" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "vds" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "zhash" }
)}

if (!$Cfg.Enabled) { return }

$AMD = @("aeternity", "beamhash", "beamhashII", "bfc", "eaglesong", "equihash125_4", "equihash144_5", "equihash192_7", "swap")

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				if ($_.Algorithm -match "zhash") { $_.Algorithm = "equihash144_5" }
				$types = if ([Config]::ActiveTypes -contains [eMinerType]::nVidia) { [eMinerType]::nVidia } else { $null }
				if ($AMD -contains $_.Algorithm) {
					if ([Config]::ActiveTypes -contains [eMinerType]::nVidia -and [Config]::ActiveTypes -contains [eMinerType]::AMD) {
						$types = @([eMinerType]::nVidia, [eMinerType]::AMD)
					}
					elseif ([Config]::ActiveTypes -contains [eMinerType]::AMD) {
						$types = [eMinerType]::AMD
					}
				}
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				$alg = "-a $($_.Algorithm)"
				if ($_.Algorithm -match "equihash" -and $extrargs -notmatch "-pers") {
					$alg = Get-Join " " @($alg, "--pers auto")
				}
				$benchsecs = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
				$runbefore = $_.RunBefore
				$runafter = $_.RunAfter
				$user = $Pool.User
				if ($user -notmatch ".$([Config]::WorkerNamePlaceholder)") {
					$user = "$user._"
				}
				$nvml = if ($extrargs -match "--nvml") { [string]::Empty } else { "--nvml 0 " }
				$types | ForEach-Object {
					if ($_) {
						$devs = if ($_ -eq [eMinerType]::nVidia) { "--cuda 1 $nvml--opencl 0" } else { "--cuda 0 --opencl 1" }
						$port = if ($_ -eq [eMinerType]::nVidia) { 42000 } else { 42001 }
						[MinerInfo]@{
							Pool = $Pool.PoolName()
							PoolKey = $Pool.PoolKey()
							Name = $Name
							Algorithm = $Algo
							Type = $_
							TypeInKey = $true
							API = "gminer"
							URI = "https://github.com/develsoftware/GMinerRelease/releases/download/1.70/gminer_1_70_windows64.zip"
							Path = "$Name\miner.exe"
							ExtraArgs = $extrargs
							Arguments = "$alg -s $($Pool.Host) -n $($Pool.PortUnsecure) -u $user -p $($Pool.Password) --api $port --pec 0 -w 0 $devs $extrargs"
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