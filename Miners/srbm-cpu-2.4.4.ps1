<#
MindMiner  Copyright (C) 2019-2023  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::CPU) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$extraThreads = $null
$extraCores = $null
if ([Config]::DefaultCPU) {
	$extraThreads = "--cpu-threads $([Config]::DefaultCPU.Threads)"
	$extraCores = "--cpu-threads $([Config]::DefaultCPU.Cores)"
}
<# else {
	$extraThreads = "--cpu-threads $(($Devices[[eMinerType]::CPU]| Measure-Object Threads -Sum).Sum)"
	$extraCores = "--cpu-threads $(($Devices[[eMinerType]::CPU]| Measure-Object Cores -Sum).Sum)"
}#>

$hasGPU = [Config]::ActiveTypes -contains [eMinerType]::AMD -or [Config]::ActiveTypes -contains [eMinerType]::nVidia

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 120
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonight_ccx" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonight_talleo" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "dynamo"; ExtraArgs = $extraThreads }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "minotaur" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "randomhash2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "scryptn2"; ExtraArgs = $extraThreads }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespowerarwn"; ExtraArgs = $extraThreads }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespoweriots" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespoweritc" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespowerlitb"; ExtraArgs = $extraThreads }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespowerres" }
)}

if (!$Cfg.Enabled) { return }

$port = [Config]::Ports[[int][eMinerType]::CPU]

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
				$tls = "false"
				if ($Pool.Protocol -match "ssl") { $tls = "true" }
				$pools = [string]::Empty
				$Pool.Hosts | ForEach-Object {
					$pools = Get-Join "!" @($pools, "$_`:$($Pool.Port)")
				}
				$fee = 0.85
				if (("aurum", "cosa", "memehash", "memehash_apepepow") -contains $_.Algorithm) { $fee = 2 }
				elseif (("ethash", "etchash", "ubqhash") -contains $_.Algorithm) { $fee = 0.65 }
				elseif (("autolykos2", "dynamo", "verthash", "pufferfish2bmb") -contains $_.Algorithm) { $fee = 1 }
				elseif (("yespowerlitb", "yespowerurx", "blake2b", "blake2s", "cryptonight_talleo", "k12", "keccak") -contains $_.Algorithm) { $fee = 0 }
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Priority = $Pool.Priority
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::CPU
					API = "srbm2"
					URI = "https://github.com/doktor83/SRBMiner-Multi/releases/download/2.4.4/SRBMiner-Multi-2-4-4-win64.zip"
					Path = "$Name\SRBMiner-MULTI.exe"
					ExtraArgs = $extrargs
					Arguments = "--algorithm $($_.Algorithm) --pool $pools --wallet $($Pool.User) --password $($Pool.Password) --tls $tls --api-enable --api-port $port --miner-priority 1 --disable-gpu --retry-time $($Config.CheckTimeout) $nicehash $extrargs"
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