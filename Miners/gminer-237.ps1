<#
MindMiner  Copyright (C) 2018-2020  Oleg Samsonov aka Quake4
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
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "beamhashIII" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "kadena" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "bfc" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cortex" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cuckaroo29" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cuckaroo29b" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cuckarood29" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cuckarood29v" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cuckaroom29" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cuckarooz29" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cuckatoo31" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cuckatoo32" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cuckoo24" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "eaglesong" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash125_4" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash144_5" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash192_7" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihashZCL" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash96_5" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "etchash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "ethash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "grimm" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "handshake" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "kawpow"; BenchmarkSeconds = 120 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "progpow" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "progpowz" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "vprogpow" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sero" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "swap" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "vds" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "zhash" }
)}

if (!$Cfg.Enabled) { return }

$AMD = @("aeternity", "beamhash", "beamhashII", "kadena", "bfc", "cuckaroo29b", "eaglesong", "equihash125_4", "equihash144_5", "equihash192_7", "equihashZCL", "etchash", "ethash", "swap")

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool -and ($Pool.Name -notmatch "nicehash" -or ($Pool.Name -match "nicehash" -and $_.Algorithm -notmatch "handshake"))) {
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
				if ($_.Algorithm -match "equihashZCL") {
					$alg = "-a equihash192_7 --pers ZcashPoW"
				}
				elseif ($_.Algorithm -match "kadena") {
					$alg = "-a blake2s"
				}
				if (($_.Algorithm -match "ethash" -or $_.Algorithm -match "etchash") -and ($Pool.Name -match "nicehash" -or $Pool.Name -match "mph")) {
					$alg = Get-Join " " @($alg, "--proto stratum")
				}
				$fee = if ($_.Algorithm -match "cortex") { 5 }
					elseif ($_.Algorithm -match "bfc" -or $_.Algorithm -match "cuckaroom29" -or $_.Algorithm -match "cuckarooz29") { 3 }
					elseif ($_.Algorithm -match "cuckarood29v") { 10 }
					elseif ($_.Algorithm -match "cuckaroo29b") { 4 }
					elseif ($_.Algorithm -match "ethash" -or $_.Algorithm -match "etchash") { 0.65 }
					else { 2 }
				$benchsecs = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
				$runbefore = $_.RunBefore
				$runafter = $_.RunAfter
				$user = $Pool.User
				if ($user -notmatch ".$([Config]::WorkerNamePlaceholder)" -and !$user.Contains(".")) {
					$user = "$user._"
				}
				$nvml = if ($extrargs -match "--nvml") { [string]::Empty } else { "--nvml 0 " }
				$pec = if ($extrargs -match "--electricity_cost") { [string]::Empty } else { "--pec 0 " }
				$hosts = [string]::Empty
				$Pool.Hosts | ForEach-Object { $hosts = Get-Join " " @($hosts, "-s $_`:$($Pool.PortUnsecure) -u $user -p $($Pool.Password)") }
				$types | ForEach-Object {
					if ($_) {
						$devs = if ($_ -eq [eMinerType]::nVidia) { "--cuda 1 $nvml--opencl 0" } else { "--cuda 0 --opencl 1" }
						$port = if ($_ -eq [eMinerType]::nVidia) { 42000 } else { 42001 }
						[MinerInfo]@{
							Pool = $Pool.PoolName()
							PoolKey = $Pool.PoolKey()
							Priority = $Pool.Priority
							Name = $Name
							Algorithm = $Algo
							Type = $_
							TypeInKey = $true
							API = "gminer"
							URI = "https://github.com/develsoftware/GMinerRelease/releases/download/2.37/gminer_2_37_windows64.zip"
							Path = "$Name\miner.exe"
							ExtraArgs = $extrargs
							Arguments = "$alg $hosts --api $port $pec-w 0 $devs $extrargs"
							Port = $port
							BenchmarkSeconds = $benchsecs
							RunBefore = $runbefore
							RunAfter = $runafter
							Fee = $fee
						}
					}
				}
			}
		}
	}
}