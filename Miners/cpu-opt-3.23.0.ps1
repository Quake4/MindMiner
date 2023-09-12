<#
MindMiner  Copyright (C) 2017-2023  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::CPU) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$extra = $null
if ([Config]::DefaultCPU) {
	$extra = "-t $([Config]::DefaultCPU.Threads)"
}

$nogpu = $([Config]::ActiveTypes -notcontains [eMinerType]::AMD -and [Config]::ActiveTypes -notcontains [eMinerType]::nVidia)

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 60
	ExtraArgs = $extra
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "allium" }
		[AlgoInfoEx]@{ Enabled = $nogpu; Algorithm = "anime" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "argon2d250" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "argon2d500" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "argon2d4096" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "axiom" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "bcd" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "blakecoin" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "blake2b" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "blake2s" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "bmw512" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "c11" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cpupower" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "decred" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "groestl" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "hex" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "hmq1725" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "hodl" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "jha" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "keccak" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "keccakc" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lbry" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2h" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2rev2" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "lyra2rev3" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2z" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2z330"; BenchmarkSeconds = 180 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "m7m" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "minotaur" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "minotaurx" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "myr-gr" }
		# [AlgoInfoEx]@{ Enabled = $true; Algorithm = "neoscrypt" } # not working
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "nist5" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "phi1612" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "phi2" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "phi2-lux" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "polytimos" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "power2b" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "quark" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "qubit" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "scryptn2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sha256d" }
		[AlgoInfoEx]@{ Enabled = $nogpu; Algorithm = "sha256dt" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sha256q" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sha256t" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sha3d" }
		[AlgoInfoEx]@{ Enabled = $nogpu; Algorithm = "sha512256d" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "skein" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "skein2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "skunk" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "timetravel" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "timetravel10" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "tribus" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "veltor" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "veil" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "verthash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x11evo" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x11gost" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x12" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x13sm3" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x16r" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x16rv2" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x16rt" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x16s" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x17" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x21s" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x22i" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x25x" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "xevan" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yescrypt" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "yescryptr8" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yescryptr8g" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yescryptr16" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yescryptr32" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespower" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespowerr16" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespoweric" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespowerltncg" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespowerlitb" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespowermgpc" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespowersugar" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespowerurx" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "zr5" }
)}

if (!$Cfg.Enabled) { return }

# choose version
$miners = [Collections.Generic.Dictionary[string, string[]]]::new()
$miners.Add("cpuminer-sse2.exe", @("SSE2"))
$miners.Add("cpuminer-aes-sse42.exe", @("AES", "SSE42"))
$miners.Add("cpuminer-avx.exe", @("AES", "AVX"))
$miners.Add("cpuminer-avx2.exe", @("AES", "AVX2"))
$miners.Add("cpuminer-avx2-sha.exe", @("SHA", "AVX2"))
$miners.Add("cpuminer-avx2-sha-vaes.exe", @("SHA", "AVX2", "VAES"))
$miners.Add("cpuminer-avx512.exe", @("AVX512"))
$miners.Add("cpuminer-avx512-sha-vaes.exe", @("SHA", "AVX512", "VAES"))

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

$port = [Config]::Ports[[int][eMinerType]::CPU]

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$add = [string]::Empty
				if ($_.Algorithm -match "phi2-lux") { $_.Algorithm = "phi2" }
				elseif ($_.Algorithm -match "scryptn2") { $_.Algorithm = "scrypt:1048576" }
				elseif ($_.Algorithm -match "cpupower") {
					$_.Algorithm = "yespower"
					$add = "-K `"CPUpower: The number of CPU working or available for proof-of-work mining`""
				}
				elseif ($_.Algorithm -match "yespowersugar") {
					$_.Algorithm = "yespower"
					$add = "-N 2048 -R 32 -K `"Satoshi Nakamoto 31/Oct/2008 Proof-of-work is essentially one-CPU-one-vote`""
				}
				elseif ($_.Algorithm -match "yespowerltncg" -or $_.Algorithm -match "yespowerlnc") {
					$_.Algorithm = "yespower"
					$add = "-N 2048 -R 32 -K `"LTNCGYES`""
				}
				elseif ($_.Algorithm -match "yespowerlitb") {
					$_.Algorithm = "yespower"
					$add = "-N 2048 -R 32 -K `"LITBpower: The number of LITB working or available for proof-of-work mining`""
				}
				elseif ($_.Algorithm -match "yespowermgpc") {
					$_.Algorithm = "yespower"
					$add = "-N 2048 -R 32 -K `"Magpies are birds of the Corvidae family.`""
				}
				elseif ($_.Algorithm -match "yespoweric") {
					$_.Algorithm = "yespower"
					$add = "-N 2048 -R 32 -K `"IsotopeC`""
				}
				elseif ($_.Algorithm -match "yespowerurx") {
					$_.Algorithm = "yespower"
					$add = "-N 2048 -R 32 -K `"UraniumX`""
				}
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Priority = $Pool.Priority
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::CPU
					API = "cpuminer"
					URI = "https://github.com/JayDDee/cpuminer-opt/releases/download/v3.23.0/cpuminer-opt-3.23.0-windows.zip"
					Path = "$Name\$bestminer"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) -o $($Pool.Protocol)://$($Pool.Hosts[0]):$($Pool.Port) -u $($Pool.User) -p $($Pool.Password) -q -b 127.0.0.1:$port --cpu-priority 1 --retry-pause $($Config.CheckTimeout) -T 500 $add $extrargs"
					Port = $port
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
				}
			}
		}
	}
}