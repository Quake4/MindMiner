<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
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
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "ethash" }
)})

if (!$Cfg.Enabled) { return }

$file = [IO.Path]::Combine($BinLocation, $Name, "epools.txt")
if ([IO.File]::Exists($file)) {
	[IO.File]::Delete($file)
}

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$esm = 1 # MiningPoolHub
				if ($Pool.Name -contains "nicehash") {
					$esm = 4
				}
				$proto = $Pool.Protocol
				if ($Pool.Protocol.Contains("ssl")) {
					$proto = "ssl"
				}
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::AMD
					TypeInKey = $true
					API = "claymore"
					URI = "http://mindminer.online/miners/nVidia/PhoenixMiner_3.0c.zip"
					Path = "$Name\PhoenixMiner.exe"
					ExtraArgs = $extrargs
					Arguments = "-pool $proto`://$($Pool.Host):$($Pool.Port) -wal $($Pool.User) -pass $($Pool.Password) -wdog 0 -proto $esm -cdmport 3350 -amd -eres 1 -log 0 -gsi 15 $extrargs"
					Port = 3350
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = 0.65
				}
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "claymore"
					URI = "http://mindminer.online/miners/nVidia/PhoenixMiner_3.0c.zip"
					Path = "$Name\PhoenixMiner.exe"
					ExtraArgs = $extrargs
					Arguments = "-pool $proto`://$($Pool.Host):$($Pool.Port) -wal $($Pool.User) -pass $($Pool.Password) -wdog 0 -proto $esm -cdmport 3360 -nvidia -eres 1 -log 0 -gsi 15 $extrargs"
					Port = 3360
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = 0.65
				}
			}
		}
	}
}