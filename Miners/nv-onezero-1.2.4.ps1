<#
MindMiner  Copyright (C) 2017-2023  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 240
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "dynex" }
)}

if (!$Cfg.Enabled) { return }

$port = [Config]::Ports[[int][eMinerType]::nVidia]

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				$fee = 3
				$mallob = [string]::Empty
				if ($_.Algorithm -match "dynex") {
					$mallob = "--mallob-endpoint mallob-ml.eu.neuropool.net,pool.deepminerz.com:9001";
				}
				$proto = [string]::Empty
				if ($Pool.Protocol -match "ssl") { $proto = "ssl://" }
				$hosts = [string]::Empty
				$Pool.Hosts | ForEach-Object { $hosts = Get-Join "," @($hosts, "$proto$_`:$($Pool.Port)") }
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Priority = $Pool.Priority
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "onezero"
					URI = "https://github.com/OneZeroMiner/onezerominer/releases/download/v1.2.4/onezerominer-win64-1.2.4.zip"
					Path = "$Name\onezerominer.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) -o $hosts -w $($Pool.User) -p $($Pool.Password) --no-cert-validation $mallob --api-host 127.0.0.1 --api-port $port $extrargs"
					Port = $port
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = $fee
				}
			}
		}
	}
}