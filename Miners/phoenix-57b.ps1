<#
MindMiner  Copyright (C) 2017-2021  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia -and [Config]::ActiveTypes -notcontains [eMinerType]::AMD) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 180
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "ethash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "etchash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "progpow" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "ubiqhash" } # isnt working on zerg
)}

if (!$Cfg.Enabled) { return }

$file = [IO.Path]::Combine($BinLocation, $Name, "epools.txt")
if ([IO.File]::Exists($file)) {
	[IO.File]::Delete($file)
}

$url = "http://mindminer.online/miners/PhoenixMiner_5.7b.zip"

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$esm = 2
				if ($Pool.Name -match "nicehash") { $esm = 4 }
				elseif ($Pool.Name -match "mph" -or $Pool.Name -match "mrr") { $esm = 1 }
				elseif ($Pool.Name -match "zergpool" -and $_.Algorithm -notmatch "ethash" -and $_.Algorithm -notmatch "etchash") { $esm = 1 }
				$proto = $Pool.Protocol
				if ($Pool.Protocol.Contains("ssl")) { $proto = "ssl" }
				$extra = [string]::Empty
				if ($_.Algorithm -match "progpow") { $extra = "-coin bci" }
				elseif ($_.Algorithm -match "ubiqhash") { $extra = "-coin ubq" }
				elseif ($_.Algorithm -match "etchash") { $extra = "-coin etc" }
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				$pools = "-pool $proto`://$($Pool.Hosts[0]):$($Pool.Port) -wal $($Pool.User) -pass $($Pool.Password)"
				if ($Pool.Hosts.Count -gt 1) {
					$pools = Get-Join " " @($pools, "-pool2 $proto`://$($Pool.Hosts[1]):$($Pool.Port) -wal2 $($Pool.User) -pass2 $($Pool.Password)")
				}
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Priority = $Pool.Priority
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::AMD
					TypeInKey = $true
					API = "claymore"
					URI = $url
					Path = "$Name\PhoenixMiner.exe"
					ExtraArgs = $extrargs
					Arguments = "$pools -wdog 0 -proto $esm -cdmport 3350 -amd -eres 1 -log 0 -gsi 30 -dagrestart 0 $extra $extrargs"
					Port = 3350
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = 0.65
				}
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Priority = $Pool.Priority
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					TypeInKey = $true
					API = "claymore"
					URI = $url
					Path = "$Name\PhoenixMiner.exe"
					ExtraArgs = $extrargs
					Arguments = "$pools -wdog 0 -proto $esm -cdmport 3360 -nvidia -eres 1 -log 0 -gsi 30 -dagrestart 0 -nvdo 1 $extra $extrargs"
					Port = 3360
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = 0.65
				}
			}
		}
	}
}