<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Include.ps1

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia -and [Config]::ActiveTypes -notcontains [eMinerType]::AMD) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $false
	BenchmarkSeconds = 120
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "ethash" }
)})

if (!$Cfg.Enabled) { return }

$file = [IO.Path]::Combine($BinLocation, $Name, "epools.txt")
if ([IO.File]::Exists($file)) {
	[IO.File]::Delete($file)
}

$file = [IO.Path]::Combine($BinLocation, $Name, "dpools.txt")
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
				$esm = 2 # MiningPoolHub
				if ($Pool.Name -contains "nicehash") {
					$esm = 3
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
					URI = "http://mindminer.online/miners/AMD/claymore/Claymore-Dual-Ethereum-AMD+NVIDIA-Miner-v11.8.zip"
					Path = "$Name\EthDcrMiner64.exe"
					ExtraArgs = $extrargs
					Arguments = "-epool $($Pool.Protocol)://$($Pool.Host):$($Pool.Port) -ewal $($Pool.User) -epsw $($Pool.Password) -retrydelay $($Config.CheckTimeout) -wd 0 -mode 1 -allpools 1 -esm $esm -mport -3350 -dbg -1 -platform 1 -eres 1 -y 1 $extrargs"
					Port = 3350
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = 1
				}
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "claymore"
					URI = "http://mindminer.online/miners/AMD/claymore/Claymore-Dual-Ethereum-AMD+NVIDIA-Miner-v11.8.zip"
					Path = "$Name\EthDcrMiner64.exe"
					ExtraArgs = $extrargs
					Arguments = "-epool $($Pool.Protocol)://$($Pool.Host):$($Pool.Port) -ewal $($Pool.User) -epsw $($Pool.Password) -retrydelay $($Config.CheckTimeout) -wd 0 -mode 1 -allpools 1 -esm $esm -mport -3360 -dbg -1 -platform 2 -eres 1 $extrargs"
					Port = 3360
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = 1
				}
			}
		}
	}
}