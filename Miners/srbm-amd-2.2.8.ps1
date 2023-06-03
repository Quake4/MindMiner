<#
MindMiner  Copyright (C) 2019-2023  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::AMD) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 120
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "0x10" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2d_16000" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2d_dynamic" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2id_chukwa" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2id_chukwa2" }
		# [AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2id_ninja" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "autolykos2" }
		# [AlgoInfoEx]@{ Enabled = $true; Algorithm = "bl2bsha3" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "blake2b" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "blake2s" } # only dual
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "blake3_alephium" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "blake3_ironfish" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "circcash" }
		# [AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonight_cache" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonight_ccx" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonight_gpu" }
		# [AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonight_heavyx" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonight_talleo" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonight_turtle" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonight_upx" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonight_xhv" }
		[AlgoInfoEx]@{ Enabled = $([Config]::ActiveTypes -notcontains [eMinerType]::CPU); Algorithm = "curvehash" }
		# [AlgoInfoEx]@{ Enabled = $true; Algorithm = "eaglesong" } # share above target on nice
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "dynex" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "etchash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "ethash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "firopow" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "frkhash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "ghostrider" }
		[AlgoInfoEx]@{ Enabled = $([Config]::ActiveTypes -notcontains [eMinerType]::CPU); Algorithm = "heavyhash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "k12" }
		# [AlgoInfoEx]@{ Enabled = $true; Algorithm = "kadena" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "kawpow" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "keccak" } # only dual
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "kaspa" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2v2_webchain" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "memehash" }
		# [AlgoInfoEx]@{ Enabled = $true; Algorithm = "phi5" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "progpow_sero" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "progpow_veil" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "progpow_zano" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "progpow_veriblock" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "progpow_epic" }
		[AlgoInfoEx]@{ Enabled = $([Config]::ActiveTypes -notcontains [eMinerType]::CPU); Algorithm = "sha256dt" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sha3d" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sha512_256d_radiant" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "ubqhash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "verthash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "verushash" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "yescrypt" } # too slow
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yescryptr8" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yescryptr16" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yescryptr32" }
)}

if (!$Cfg.Enabled) { return }

$port = [Config]::Ports[[int][eMinerType]::AMD]

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool -and !($Pool.Name -match "mph" -and ("ethash", "etchash") -contains $_.Algorithm)) {
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
				if (("cosa", "memehash") -contains $_.Algorithm) { $fee = 2 }
				elseif (("dynex") -contains $_.Algorithm) { $fee = 2.5 }
				elseif (("argon2d_16000") -contains $_.Algorithm) { $fee = 76 }
				elseif (("ethash", "etchash", "ubqhash") -contains $_.Algorithm) { $fee = 0.65 }
				elseif (("autolykos2", "dynamo", "verthash", "pufferfish2bmb") -contains $_.Algorithm) { $fee = 1 }
				elseif (("yespowerlitb", "yespowerurx", "blake2b", "blake2s", "cryptonight_talleo", "k12", "keccak") -contains $_.Algorithm) { $fee = 0 }
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Priority = $Pool.Priority
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::AMD
					API = "srbm2"
					URI = "https://github.com/doktor83/SRBMiner-Multi/releases/download/2.2.8/SRBMiner-Multi-2-2-8-win64.zip"
					Path = "$Name\SRBMiner-MULTI.exe"
					ExtraArgs = $extrargs
					Arguments = "--algorithm $($_.Algorithm) --pool $pools --wallet $($Pool.User) --password $($Pool.Password) --tls $tls --api-enable --api-port $port --disable-cpu --disable-gpu-nvidia --disable-gpu-intel --retry-time $($Config.CheckTimeout) $nicehash $extrargs"
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