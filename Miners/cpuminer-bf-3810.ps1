<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::CPU) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $true
	BenchmarkSeconds = 60
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "allium" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2d500" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2z" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yescrypt" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yescryptr8" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yescryptr16" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yescryptr24" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yescryptr32" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespower" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespowerr8" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespowerr16" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespowerr24" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yespowerr32" }
)})

if (!$Cfg.Enabled) { return }

# choose version
$miners = [Collections.Generic.Dictionary[string, string[]]]::new()
$miners.Add("cpuminer-sse2.exe", @("SSE2"))
if ([Config]::Is64Bit) {
	$miners.Add("cpuminer-aes-sse42.exe", @("AES", "SSE42"))
	$miners.Add("cpuminer-avx.exe", @("AES", "AVX"))
	$miners.Add("cpuminer-avx2.exe", @("AES", "AVX2"))
	$miners.Add("cpuminer-avx2-sha.exe", @("SHA", "AVX2"))
}

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

$url = if ([Config]::Is64Bit) { "https://github.com/bellflower2015/cpuminer-opt/releases/download/v3.8.10-bf/cpuminer-opt-v3.8.10-bf-win64.zip" } else { "https://github.com/bellflower2015/cpuminer-opt/releases/download/v3.8.10-bf/cpuminer-opt-v3.8.10-bf-win32.zip" }

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
					URI = $url
					Path = "$Name\$bestminer"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) -o stratum+tcp://$($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -q -b 4048 --cpu-priority 0 -R $($Config.CheckTimeout) $extrargs"
					Port = 4048
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
				}
			}
		}
	}
}
