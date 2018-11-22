<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $false
	BenchmarkSeconds = 90
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "aergo" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "bcd" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "bitcore" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "c11"; ExtraArgs = "-i 21" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "hex" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "hsr"; ExtraArgs = "-i 21" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "phi" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "phi2" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "poly"; BenchmarkSeconds = 120 }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "renesis" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "skunk" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "sonoa" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "timetravel" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "tribus"; BenchmarkSeconds = 120 }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "vit" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x16r"; BenchmarkSeconds = 120 }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x16s"; BenchmarkSeconds = 120 }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x17"; BenchmarkSeconds = 120; ExtraArgs = "-i 21" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "xevan"; BenchmarkSeconds = 120 }
)}

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				if ($_.Algorithm -notmatch "hex") {
				$N = Get-CCMinerStatsAvg $Algo $_
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = if ($Algo -match "x16.") { "ccminer_woe" } else { "ccminer" }
					URI = "http://mindminer.online/miners/nVidia/z-enemy.124-92v3.zip"
					Path = "$Name\z-enemy.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) -o stratum+tcp://$($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -R $($Config.CheckTimeout) -q $N $extrargs"
					Port = 4068
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = 1
				}}
			}
		}
	}
}