<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $true
	BenchmarkSeconds = 90
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "balloon" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "bcd" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "bitcore" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "c11" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "hmq1725" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "hsr" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "lyra2z" } # dredge faster
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "phi" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "polytimos" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "renesis" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "skunk" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sonoa" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "tribus"; BenchmarkSeconds = 120 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x16r"; BenchmarkSeconds = 120 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x16s"; BenchmarkSeconds = 120 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x17"; BenchmarkSeconds = 120 }
)})

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$BenchSecs = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
				$N = "-N $([Convert]::ToInt32($BenchSecs/2))" #Get-CCMinerStatsAvg $Algo $_
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "ccminer_woe"
					URI = "http://mindminer.online/miners/nVidia/t-rex-0610.zip"
					Path = "$Name\t-rex.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) -o stratum+tcp://$($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) --retry-pause $($Config.CheckTimeout) -b 127.0.0.1:4068 --quiet $N $extrargs"
					Port = 4068
					BenchmarkSeconds = $BenchSecs
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = 1
				}
			}
		}
	}
}
