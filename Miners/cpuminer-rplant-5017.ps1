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
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "balloon" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cpupower" }
		# [AlgoInfoEx]@{ Enabled = $true; Algorithm = "curvehash" } # wrong api speed
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "hodl" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "heavyhash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "gr" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "qureno" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2tdc" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2z330"; BenchmarkSeconds = 180 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "phi5" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "power2b" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sha256csm" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x22" }
		# [AlgoInfoEx]@{ Enabled = $true; Algorithm = "yescrypt" } # no algo
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "yescryptr8" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yescryptr8glt" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yescryptr8g" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yescryptr16" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yescryptr16v2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yescryptr16v2glt" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yescryptr24" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yescryptr24glt" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yescryptr32" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yescryptr32glt" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespower" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespowerr16" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespowerURX" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespowerIC" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespowerITC" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespowerIOTS" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespowerSUGAR" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespowerTIDE" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespowerLTNCG" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespowerRES" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespowerLITB" }
)}

if (!$Cfg.Enabled) { return }

# choose version
$miners = [Collections.Generic.Dictionary[string, string[]]]::new()
$miners.Add("cpuminer-sse2.exe", @("SSE2"))
# $miners.Add("cpuminer-sse42.exe", @("SSE42"))
$miners.Add("cpuminer-sse42-aes.exe", @("AES", "SSE42"))
$miners.Add("cpuminer-avx.exe", @("AES", "AVX"))
$miners.Add("cpuminer-avx2.exe", @("AES", "AVX2"))
$miners.Add("cpuminer-ryzen.exe", @("SHA", "AVX2"))
$miners.Add("cpuminer-avx512.exe", @("AVX512"))

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
		if ($Algo -and $Algo -notmatch "curvehash") {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				if ($_.Algorithm -match "phi2-lux") { $_.Algorithm = "phi2" }
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Priority = $Pool.Priority
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::CPU
					API = "cpuminer"
					URI = "https://github.com/rplant8/cpuminer-opt-rplant/releases/download/5.0.17/cpuminer-opt-win.zip"
					Path = "$Name\$bestminer"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) -o stratum+tcp://$($Pool.Hosts[0]):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) --rig-id $([Config]::WorkerNamePlaceholder) -q -b 4048 --no-doh --cpu-priority 1 --retry-pause $($Config.CheckTimeout) -T 500 $extrargs"
					Port = 4048
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
				}
			}
		}
	}
}