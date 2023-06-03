<#
MindMiner  Copyright (C) 2019-2023  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 120
	ExtraArgs = $null
	Algorithms = @(
		@{ Enabled = $true; Algorithm = "autolykos2"; DualAlgorithm = "kaspa" }
		@{ Enabled = $true; Algorithm = "autolykos2"; DualAlgorithm = "blake3_alephium" }
		@{ Enabled = $true; Algorithm = "autolykos2"; DualAlgorithm = "blake3_ironfish" }
		@{ Enabled = $true; Algorithm = "autolykos2"; DualAlgorithm = "heavyhash" }
		@{ Enabled = $true; Algorithm = "autolykos2"; DualAlgorithm = "sha256dt" }
		@{ Enabled = $true; Algorithm = "autolykos2"; DualAlgorithm = "sha512_256d_radiant" }
		@{ Enabled = $true; Algorithm = "dynex"; DualAlgorithm = "kaspa" }
		@{ Enabled = $true; Algorithm = "dynex"; DualAlgorithm = "blake3_alephium" }
		@{ Enabled = $true; Algorithm = "dynex"; DualAlgorithm = "blake3_ironfish" }
		@{ Enabled = $true; Algorithm = "dynex"; DualAlgorithm = "heavyhash" }
		@{ Enabled = $true; Algorithm = "dynex"; DualAlgorithm = "sha256dt" }
		@{ Enabled = $true; Algorithm = "dynex"; DualAlgorithm = "sha512_256d_radiant" }
		@{ Enabled = $true; Algorithm = "etchash"; DualAlgorithm = "kaspa" }
		@{ Enabled = $true; Algorithm = "etchash"; DualAlgorithm = "blake3_alephium" }
		@{ Enabled = $true; Algorithm = "etchash"; DualAlgorithm = "blake3_ironfish" }
		@{ Enabled = $true; Algorithm = "etchash"; DualAlgorithm = "heavyhash" }
		@{ Enabled = $true; Algorithm = "etchash"; DualAlgorithm = "sha256dt" }
		@{ Enabled = $true; Algorithm = "etchash"; DualAlgorithm = "sha512_256d_radiant" }
		@{ Enabled = $true; Algorithm = "ethash"; DualAlgorithm = "kaspa" }
		@{ Enabled = $true; Algorithm = "ethash"; DualAlgorithm = "blake3_alephium" }
		@{ Enabled = $true; Algorithm = "ethash"; DualAlgorithm = "blake3_ironfish" }
		@{ Enabled = $true; Algorithm = "ethash"; DualAlgorithm = "heavyhash" }
		@{ Enabled = $true; Algorithm = "ethash"; DualAlgorithm = "sha256dt" }
		@{ Enabled = $true; Algorithm = "ethash"; DualAlgorithm = "sha512_256d_radiant" }
)}

if (!$Cfg.Enabled) { return }

$port = [Config]::Ports[[int][eMinerType]::nVidia]

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		$AlgoDual = Get-Algo($_.DualAlgorithm)
		if ($Algo -and $AlgoDual -and !($Pool.Name -match "mph" -and ("ethash", "etchash") -contains $_.Algorithm)) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			$PoolDual = Get-Pool($AlgoDual)
			if ($Pool -and $PoolDual) {
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				<#$nicehash = "--nicehash false"
				if ($Pool.Name -match "nicehash") {
					$nicehash = "--nicehash true"
				}#>
				$tls = "false"
				if ($Pool.Protocol -match "ssl") { $tls = "true" }
				$pools = [string]::Empty
				$Pool.Hosts | ForEach-Object {
					$pools = Get-Join "!" @($pools, "$_`:$($Pool.Port)")
				}
				$tlsDual = "false"
				if ($PoolDual.Protocol -match "ssl") { $tlsDual = "true" }
				$poolsDual = [string]::Empty
				$PoolDual.Hosts | ForEach-Object {
					$poolsDual = Get-Join "!" @($poolsDual, "$_`:$($PoolDual.Port)")
				}
				$fee = 0.85
				if (("cosa", "memehash") -contains $_.Algorithm) { $fee = 2 }
				elseif (("dynex") -contains $_.Algorithm) { $fee = 2.5 }
				elseif (("ethash", "etchash", "ubqhash") -contains $_.Algorithm) { $fee = 0.65 }
				elseif (("autolykos2", "dynamo", "verthash", "pufferfish2bmb") -contains $_.Algorithm) { $fee = 1 }
				elseif (("yespowerlitb", "yespowerurx", "blake2b", "blake2s", "cryptonight_talleo", "k12", "keccak") -contains $_.Algorithm) { $fee = 0 }
				[MinerInfo]@{
					Pool = $(Get-FormatDualPool $Pool.PoolName() $PoolDual.PoolName())
					PoolKey = "$($Pool.PoolKey())+$($PoolDual.PoolKey())"
					Priority = $Pool.Priority
					DualPriority = $PoolDual.Priority
					Name = $Name
					Algorithm = $Algo
					DualAlgorithm = $AlgoDual
					Type = [eMinerType]::nVidia
					API = "srbm2"
					URI = "https://github.com/doktor83/SRBMiner-Multi/releases/download/2.2.8/SRBMiner-Multi-2-2-8-win64.zip"
					Path = "$Name\SRBMiner-MULTI.exe"
					ExtraArgs = $extrargs
					Arguments = "--algorithm $($_.Algorithm) --pool $pools --wallet $($Pool.User) --password $($Pool.Password) --tls $tls --algorithm $($_.DualAlgorithm) --pool $poolsDual --wallet $($PoolDual.User) --password $($PoolDual.Password) --tls $tlsDual --api-enable --api-port $port --disable-cpu --disable-gpu-amd --disable-gpu-intel --retry-time $($Config.CheckTimeout) $extrargs"
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