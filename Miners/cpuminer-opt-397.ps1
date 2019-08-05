<#
MindMiner  Copyright (C) 2017-2019  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::CPU) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 60
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "allium" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2d250" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2d500" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2d4096" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "axiom" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "bcd" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "blakecoin" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "blake2b" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "blake2s" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "bmw512" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "c11" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "cryptonight" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "cryptonightv7" } # jce faster
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "decred" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "groestl" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "hex" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "hmq1725" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "hodl" } # error with stop mining
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "jha" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "keccak" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "keccakc" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lbry" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2h" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2rev2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2rev3" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2z" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2z330"; BenchmarkSeconds = 180 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "m7m" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "myr-gr" }
		# [AlgoInfoEx]@{ Enabled = $true; Algorithm = "neoscrypt" } # not working
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "nist5" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "phi1612" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "phi2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "polytimos" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "quark" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "qubit" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sha256d" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sha256q" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sha256t" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "skein" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "skein2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "skunk" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "timetravel" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "timetravel10" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "tribus" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "veltor" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "veil" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x11evo" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x11gost" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x12" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x13sm3" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x16r" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x16rt" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x16s" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x17" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x21s" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "xevan" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yescrypt" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yescryptr8" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yescryptr16" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yescryptr32" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespower" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespowerr16" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "zr5" }
)}

if (!$Cfg.Enabled) { return }

# choose version
$miners = [Collections.Generic.Dictionary[string, string[]]]::new()
$miners.Add("cpuminer-sse2.exe", @("SSE2"))
$miners.Add("cpuminer-aes-sse42.exe", @("AES", "SSE42"))
$miners.Add("cpuminer-avx.exe", @("AES", "AVX"))
$miners.Add("cpuminer-avx2.exe", @("AES", "AVX2"))
$miners.Add("cpuminer-zen.exe", @("SHA", "AVX2"))

$bestminer = $null
$miners.GetEnumerator() | ForEach-Object {
	$has = $true
	$_.Value | ForEach-Object {
		if (![Config]::CPUFeatures.Contains($_)) {
			$has = $false
		}
	}
	if ($has) {
		$bestminer = $_.Key
	}
}
if (!$bestminer) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::CPU
					API = "cpuminer"
					URI = "https://github.com/JayDDee/cpuminer-opt/releases/download/v3.9.7/cpuminer-opt-3.9.7-windows.zip"
					Path = "$Name\$bestminer"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) -o stratum+tcp://$($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -q -b 4048 --cpu-priority 1 --retry-pause $($Config.CheckTimeout) -T 500 $extrargs"
					Port = 4048
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
				}
			}
		}
	}
}