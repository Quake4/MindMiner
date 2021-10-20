<#
MindMiner  Copyright (C) 2017-2021  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::CPU) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$extra = [string]::Empty
if ([Config]::DefaultCPU) {
	$extra = "-t $([Config]::DefaultCPU.Threads)"
}

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 120
	ExtraArgs = $extra
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "gr" }
)}

if (!$Cfg.Enabled) { return }

# choose version
$miners = [Collections.Generic.Dictionary[string, string[]]]::new()
$miners.Add("cpuminer-sse2.exe", @("SSE2"))
$miners.Add("cpuminer-aes-sse42.exe", @("AES", "SSE42"))
$miners.Add("cpuminer-avx.exe", @("AES", "AVX"))
$miners.Add("cpuminer-avx2.exe", @("AES", "AVX2"))
$miners.Add("cpuminer-zen.exe", @("SHA", "AVX2"))
$miners.Add("cpuminer-zen3.exe", @("SHA", "AVX2", "VAES"))
$miners.Add("cpuminer-avx512.exe", @("AVX512"))
$miners.Add("cpuminer-avx512-sha.exe", @("SHA", "AVX512"))
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
				elseif ($_.Algorithm -match "yespowerlnc") {
					$_.Algorithm = "yespower"
					$add = "-N 2048 -R 32 -K `"LTNCGYES`""
				}
				elseif ($_.Algorithm -match "yespowerlitb") {
					$_.Algorithm = "yespower"
					$add = "-N 2048 -R 32 -K `"LITBpower: The number of LITB working or available for proof-of-work mini`""
				}
				elseif ($_.Algorithm -match "yespoweric") {
					$_.Algorithm = "yespower"
					$add = "-N 2048 -R 32 -K `"IsotopeC`""
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
					URI = "https://github.com/WyvernTKC/cpuminer-gr-avx2/releases/download/1.2.2/cpuminer-gr-1.2.2-x86_64_windows.7z"
					Path = "$Name\$bestminer"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) -o stratum+tcp://$($Pool.Hosts[0]):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -q -b 127.0.0.1:4048 --cpu-priority 1 --retry-pause $($Config.CheckTimeout) -T 500 $add $extrargs"
					Port = 4048
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = 1.75
				}
			}
		}
	}
}