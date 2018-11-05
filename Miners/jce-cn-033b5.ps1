<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::AMD) { exit }
if (![Config]::Is64Bit) { exit }
if ([Environment]::OSVersion.Version -lt [Version]::new(8, 1)) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $true
	BenchmarkSeconds = 90
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "cryptonight" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightheavy" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightv7" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightv8" }
)})

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				$add = [string]::Empty
				$fee = 1
				if ($extrargs -notmatch "--variation") {
					switch ($_.Algorithm) {
						"cryptonight" { $add = "--variation 1" }
						"cryptonightheavy" { $add = "--variation 5"; $fee = 2.5 }
						"cryptonightv7" { $add = "--variation 3" }
						"cryptonightv8" { $add = "--variation 15" }
					}
				}
				if (!$extrargs.Contains("-c")) { $add = Get-Join " " @($add, "--auto") }
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::AMD
					API = "jce"
					URI = "https://github.com/jceminer/cn_gpu_miner/raw/master/jce_cn_gpu_miner.033b5.zip"
					Path = "$Name\jce_cn_gpu_miner64.exe"
					ExtraArgs = $extrargs
					Arguments = "-o $($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) --forever --any --mport 4028 --no-cpu $add $extrargs"
					Port = 4028
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = $fee
				}
			}
		}
	}
}