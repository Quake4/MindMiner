<#
MindMiner  Copyright (C) 2018-2023  Oleg Samsonov aka Quake4
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
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "autolykos2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "beamhash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cortex" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cuckatoo32" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "dero" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash125_4" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash144_5" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash210_9" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "etchash"; BenchmarkSeconds = 120 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "ethash"; BenchmarkSeconds = 120 }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "ethash"; ExtraArgs = "--oc 0" ; BenchmarkSeconds = 180 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "firo" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "ironfish" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "karlsenhash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "kawpow"; BenchmarkSeconds = 120 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "kheavyhash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "octopus" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "progpow" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sero" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "radiant" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "vds" }
)}

if (!$Cfg.Enabled) { return }

$AMD = @("aeternity", "beamhash", "bfc", "cuckatoo32", "equihash125_4", "equihash144_5", "etchash", "ethash", "kawpow", "progpow")

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo -and $_.Algorithm -notmatch "zhash") {
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
				if (($_.Algorithm -match "ethash" -or $_.Algorithm -match "etchash") -and ($Pool.Name -match "nicehash" -or $Pool.Name -match "mph")) {
					$alg = Get-Join " " @($alg, "--proto stratum")
				}
				$fee = if (("cortex", "dero") -contains $_.Algorithm) { 5 }
					elseif (("bfc", "cuckaroom29", "firopow", "octopus") -contains $_.Algorithm) { 3 }
					elseif (("ethash", "etchash", "karlsenhash", "kheavyhash") -contains $_.Algorithm) { 1 }
					else { 2 }
				$benchsecs = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
				$runbefore = $_.RunBefore
				$runafter = $_.RunAfter
				$user = $Pool.User
				if ($user -notmatch ".$([Config]::WorkerNamePlaceholder)" -and !$user.Replace([Config]::WalletPlaceholder, ([string]::Empty)).Contains(".")) {
					$user = "$user.$([Config]::WorkerNamePlaceholder)"
				}
				$pec = if ($extrargs -match "--electricity_cost") { [string]::Empty } else { "--pec 0 " }
				$ssl = "0"
				if ($Pool.Protocol -match "ssl") { $ssl = "1" }
				$hosts = [string]::Empty
				$Pool.Hosts | ForEach-Object { $hosts = Get-Join " " @($hosts, "-s $_`:$($Pool.Port) -u $user -p $($Pool.Password) --ssl $ssl") }
				$types | ForEach-Object {
					if ($_) {
						$devs = if ($_ -eq [eMinerType]::nVidia) { "--cuda 1 --opencl 0" } else { "--cuda 0 --opencl 1" }
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
							URI = "https://github.com/develsoftware/GMinerRelease/releases/download/3.44/gminer_3_44_windows64.zip"
							Path = "$Name\miner.exe"
							ExtraArgs = $extrargs
							Arguments = "$alg $hosts --api 127.0.0.1:$port $pec-w 0 $devs $extrargs"
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