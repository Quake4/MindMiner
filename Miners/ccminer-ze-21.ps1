<#
MindMiner  Copyright (C) 2018-2019  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if (![Config]::Is64Bit) { exit }
if ([Config]::CudaVersion -lt [version]::new(9, 1)) { return }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 90
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "aergo" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "bcd" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "bitcore" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "c11" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "hex" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "hsr" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "phi" } # t-rex faster
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "phi2" } # t-rex faster
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "poly"; BenchmarkSeconds = 120 } # t-rex faster
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "skunk" } # t-rex faster
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "sonoa" } # t-rex faster
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "timetravel" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "tribus"; BenchmarkSeconds = 120 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "vit" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x16r"; BenchmarkSeconds = 120 } # t-rex faster
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x16r"; BenchmarkSeconds = 120; ExtraArgs="-i 22" }  # t-rex faster
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x16s"; BenchmarkSeconds = 120 } # t-rex faster
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x17"; BenchmarkSeconds = 120 } # t-rex faster
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "xevan"; BenchmarkSeconds = 120 }
)}

if (!$Cfg.Enabled) { return }

switch ([Config]::CudaVersion) {
	{ $_ -ge [version]::new(10, 0) } { $url = "http://mindminer.online/miners/nVidia/z-enemy-2.1-cuda10.0.zip" }
	([version]::new(9, 2)) { $url = "http://mindminer.online/miners/nVidia/z-enemy-2.1-cuda9.2.zip" }
	default { $url =  "http://mindminer.online/miners/nVidia/z-enemy-2.1-cuda9.1.zip" }
}

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$N = Get-CCMinerStatsAvg $Algo $_
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "ccminer"
					URI = $url
					Path = "$Name\z-enemy.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) -o stratum+tcp://$($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -R $($Config.CheckTimeout) -q $N $extrargs"
					Port = 4068
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = 1
				}
			}
		}
	}
}