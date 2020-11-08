<#
MindMiner  Copyright (C) 2017-2020  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $true
	BenchmarkSeconds = 180
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "aeternity" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "aeternity"; ExtraArgs = "-nofee" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "beamhash2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "beamhash2"; ExtraArgs = "-nofee" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "beamhash3" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "beamhash3"; ExtraArgs = "-nofee" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "conflux" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "conflux"; ExtraArgs = "-nofee" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "cuckaroo29m" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cuckaroo29m"; ExtraArgs = "-nofee" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "cuckaroo29z" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cuckaroo29z"; ExtraArgs = "-nofee" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "cuckatoo31" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cuckatoo31"; ExtraArgs = "-nofee" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "cuckatoo32" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cuckatoo32"; ExtraArgs = "-nofee" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash"; ExtraArgs = "-nofee" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihash144" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihash144"; ExtraArgs = "-nofee" } # gminer faster
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihashBTG" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihashBTG"; ExtraArgs = "-nofee" }  # gminer faster
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "ethash"; }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "ethash"; ExtraArgs = "-nofee" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "ethash"; ExtraArgs = "-nofee -fast" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "qitmeer"; }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "qitmeer"; ExtraArgs = "-nofee" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "raven" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "raven"; ExtraArgs = "-nofee" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "sero" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sero"; ExtraArgs = "-nofee" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "tensority" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "tensority"; ExtraArgs = "-nofee" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "zhash" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "zhash"; ExtraArgs = "-nofee" } # gminer faster
)})

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool -and ($Pool.Name -notmatch "nicehash" -or ($Pool.Name -match "nicehash" -and $_.Algorithm -notmatch "aeternity"))) {
				$proto = $_.Algorithm
				$pers = [string]::Empty
				# if (!$Pool.Protocol.Contains("ssl")) {
				# 	$proto = "stratum"
				# }
				if ($Algo -contains "ethash") {
					$proto = "ethstratum"
				}
				elseif ($Algo -contains "equihashBTG") {
					$proto = "zhash"
					$pers = "-pers BgoldPoW"
				}
				elseif ($Algo -contains "zhash" -or $Algo -contains "equihash144") {
					$proto = "equihash1445"
					$pers = "-pers auto"
				}
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				$fee = if ($extrargs.ToLower().Contains("nofee")) { 0 } else { if ($Algo -contains "ethash") { 0.65 } elseif ($Algo -contains "grin") { 1 } else { 2 } }
				if ($_.Algorithm -match "cuckatoo32") { $fee += 25; } # fix fake grin32 speed
				$hosts = [string]::Empty
				$Pool.Hosts | ForEach-Object { $hosts = Get-Join "," @($hosts, "$proto`://$($Pool.User):$($Pool.Password.Replace(",", "%2C").Replace("/", "%2F"))@$_`:$($Pool.Port)") }
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Priority = $Pool.Priority
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "bminer"
					URI = "https://www.bminercontent.com/releases/bminer-lite-v16.3.4-88bf7b3-amd64.zip"
					Path = "$Name\bminer.exe"
					ExtraArgs = $extrargs
					Arguments = "-uri $hosts -watchdog=false -api 127.0.0.1:1880 $pers $extrargs"
					Port = 1880
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = $fee
				}
			}
		}
	}
}