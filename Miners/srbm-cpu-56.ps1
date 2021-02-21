<#
MindMiner  Copyright (C) 2019-2021  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::CPU) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$extraThreads = [string]::Empty
$extraCores = [string]::Empty
if ([Config]::DefaultCPU) {
	$extraThreads = "--cpu-threads $([Config]::DefaultCPU.Threads)"
	$extraCores = "--cpu-threads $([Config]::DefaultCPU.Cores)"
}

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 60
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "m7mv2" }
)}

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				$nicehash = "--nicehash false"
				if ($Pool.Name -match "nicehash") {
					$nicehash = "--nicehash true"
				}
				$fee = 0.85
				if ($_.Algorithm -match "cryptonight_bbc") { $fee = 2 }
				elseif (("ethash", "etchash", "ubqhash") -contains $_.Algorithm) { $fee = 0.65 }
				elseif (("m7mv2", "yespoweritc", "yespowerurx", "cryptonight_catalans", "cryptonight_heavyx", "cryptonight_talleo", "keccak") -contains $_.Algorithm) { $fee = 0 }
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Priority = $Pool.Priority
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::CPU
					API = "srbm2"
					URI = "https://github.com/doktor83/SRBMiner-Multi/releases/download/0.5.6/SRBMiner-Multi-0-5-6-win64.zip"
					Path = "$Name\SRBMiner-MULTI.exe"
					ExtraArgs = $extrargs
					Arguments = "--algorithm $($_.Algorithm) --pool $($Pool.Hosts[0]):$($Pool.PortUnsecure) --wallet $($Pool.User) --password $($Pool.Password) --tls false --disable-gpu --api-enable --api-port 4045 --miner-priority 1 --retry-time $($Config.CheckTimeout) --send-stales true $nicehash $extrargs"
					Port = 4045
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = $fee
				}
			}
		}
	}
}