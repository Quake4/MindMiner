<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::AMD) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $true
	BenchmarkSeconds = 90
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "cryptonight"; ExtraArgs = "--variation 1" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightv7"; ExtraArgs = "--variation 3" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightheavy"; ExtraArgs = "--variation 5" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightv8"; ExtraArgs = "--variation 15" }
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
				if (!$extrargs.Contains("-c")) { $extrargs = Get-Join " " @("--auto", $extrargs) }
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::AMD
					API = "jce"
					URI = "https://github.com/jceminer/cn_gpu_miner/raw/master/jce_cn_gpu_miner.033b2.zip"
					Path = "$Name\jce_cn_gpu_miner64.exe"
					ExtraArgs = $extrargs
					Arguments = "-o $($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) --forever --any --mport 4028 --no-cpu $extrargs"
					Port = 4028
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = 1
				}
			}
		}
	}
}