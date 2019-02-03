<#
MindMiner  Copyright (C) 2017-2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $true
	BenchmarkSeconds = 90
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "aeternity" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "aeternity"; ExtraArgs = "-nofee" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "beam" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "beam"; ExtraArgs = "-nofee" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash"; ExtraArgs = "-nofee" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihash144" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash144"; ExtraArgs = "-nofee" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihashBTG" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihashBTG"; ExtraArgs = "-nofee" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "ethash"; BenchmarkSeconds = 180 }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "ethash"; BenchmarkSeconds = 180; ExtraArgs = "-nofee" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "grin" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "grin"; ExtraArgs = "-nofee" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "tensority" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "tensority"; ExtraArgs = "-nofee" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "zhash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "zhash"; ExtraArgs = "-nofee" }
)})

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool -and ($Pool.Name -notcontains "nicehash" -or ($Pool.Name -contains "nicehash" -and $_.Algorithm -notmatch "grin" -and $_.Algorithm -notmatch "beam"))) {
				$proto = $Pool.Protocol
				$pers = [string]::Empty
				if (!$Pool.Protocol.Contains("ssl")) {
					$proto = "stratum"
				}
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
				elseif ($Algo -contains "aeternity") {
					$proto = "aeternity"
				}
				elseif ($Algo -contains "beam") {
					$proto = "beam"
				}
				elseif ($Algo -contains "grin") {
					$proto = "cuckaroo29"
				}
				elseif ($Algo -contains "tensority") {
					$proto = "tensority"
				}
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "bminer"
					URI = "https://www.bminercontent.com/releases/bminer-lite-v14.1.0-373029c-amd64.zip"
					Path = "$Name\bminer.exe"
					ExtraArgs = $extrargs
					Arguments = "-uri $proto`://$($Pool.User):$($Pool.Password.Replace(",", "%2C").Replace("/", "%2F"))@$($Pool.Host):$($Pool.Port) -watchdog=false -api 127.0.0.1:1880 $pers $extrargs"
					Port = 1880
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = if ($extrargs.ToLower().Contains("nofee")) { 0 } else { if ($Algo -contains "ethash") { 0.65 } else { 2 } }
				}
			}
		}
	}
}