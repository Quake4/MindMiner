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
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "balloon_zentoshi" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2id_chukwa2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2id_ninja" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "autolykos2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "circcash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cpupower"; ExtraArgs = $extraCores }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "curvehash"; ExtraArgs = $extraThreads }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "minotaur" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "panthera" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "phi5" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "randomarq"; ExtraArgs = $extraThreads }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "randomepic" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "randomhash2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "randomkeva" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "randomsfx"; ExtraArgs = $extraCores }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "randomwow"; ExtraArgs = $extraThreads }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "randomx"; ExtraArgs = $extraCores }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "randomxl" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "rx2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "scryptn2"; ExtraArgs = $extraThreads }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "verushash"; ExtraArgs = $extraThreads }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yescrypt"; ExtraArgs = $extraThreads }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yescryptr16"; ExtraArgs = $extraCores }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yescryptr32"; ExtraArgs = $extraCores }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "yescryptr8" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespower"; ExtraArgs = $extraCores }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespower2b"; ExtraArgs = $extraCores }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespoweric"; ExtraArgs = $extraCores }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespoweriots" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespoweritc" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespowerlitb"; ExtraArgs = $extraCores }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespowerltncg" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespowerr16"; ExtraArgs = $extraCores }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespowerres" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespowersugar"; ExtraArgs = $extraCores }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespowertide" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespowerurx" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "verthash" }
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
				if (("cryptonight_bbc", "autolykos2") -contains $_.Algorithm) { $fee = 2 }
				elseif (("ethash", "etchash", "ubqhash") -contains $_.Algorithm) { $fee = 0.65 }
				elseif (("rx2", "verthash") -contains $_.Algorithm) { $fee = 1.25 }
				elseif (("m7mv2", "randomxl", "yespoweritc", "yespowerurx", "cryptonight_catalans", "cryptonight_heavyx", "cryptonight_talleo", "keccak") -contains $_.Algorithm) { $fee = 0 }
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Priority = $Pool.Priority
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::CPU
					API = "srbm2"
					URI = "https://github.com/doktor83/SRBMiner-Multi/releases/download/0.6.9/SRBMiner-Multi-0-6-9-win64.zip"
					Path = "$Name\SRBMiner-MULTI.exe"
					ExtraArgs = $extrargs
					Arguments = "--algorithm $($_.Algorithm) --pool $($Pool.Hosts[0]):$($Pool.PortUnsecure) --wallet $($Pool.User) --password $($Pool.Password) --tls false --api-enable --api-port 4045 --miner-priority 1 --disable-gpu --retry-time $($Config.CheckTimeout) $nicehash $extrargs"
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