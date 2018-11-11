<#
MindMiner  Copyright (C) 2017-2018  Oleg Samsonov aka Quake4
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
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "ethash" }
)}

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$proto = $Pool.Protocol.Replace("stratum", "stratum2");
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::AMD
					TypeInKey = $true
					API = "claymore"
					URI = "https://github.com/ethereum-mining/ethminer/releases/download/v0.16.0rc1/ethminer-0.16.0rc1-windows-amd64.zip"
					Path = "$Name\ethminer.exe"
					ExtraArgs = $extrargs
					Arguments = "-P $proto`://$($Pool.User):$($Pool.Password.Replace(",", "%2C").Replace("/", "%2F"))@$($Pool.Host):$($Pool.Port) --api-bind 127.0.0.1:-3350 --display-interval 60 -G --opencl-platform $([Config]::AMDPlatformId) $extrargs"
					Port = 3350
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
				}
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "claymore"
					URI = "https://github.com/ethereum-mining/ethminer/releases/download/v0.16.0rc1/ethminer-0.16.0rc1-windows-amd64.zip"
					Path = "$Name\ethminer.exe"
					ExtraArgs = $extrargs
					Arguments = "-P $proto`://$($Pool.User):$($Pool.Password.Replace(",", "%2C").Replace("/", "%2F"))@$($Pool.Host):$($Pool.Port) --api-bind 127.0.0.1:-3360 --display-interval 60 -U $extrargs"
					Port = 3360
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
				}
			}
		}
	}
}