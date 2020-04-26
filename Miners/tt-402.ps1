<#
MindMiner  Copyright (C) 2018-2020  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if (![Config]::Is64Bit) { exit }
if ([Config]::CudaVersion -lt [version]::new(9, 2)) { return }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 120
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "blake2s" }		
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "eaglesong" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "ethash" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "lyra2v3" } # dredge faster
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "tethashv1" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "kawpow" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "mtp" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "progpow" } # isn't support bci on zerg
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "progpowh" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "progpowz" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "ubqhash" }
)}

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$user = $Pool.User -replace ".$([Config]::WorkerNamePlaceholder)"
				$alg = $_.Algorithm.ToUpper()
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				$hosts = [string]::Empty
				$Pool.Hosts | ForEach-Object {
					$hosts = Get-Join " " @($hosts, "-P $user.$([Config]::WorkerNamePlaceholder):$($Pool.Password.Replace(",", "%2C").Replace("/", "%2F"))@$_`:$($Pool.PortUnsecure)")
				}
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Priority = $Pool.Priority
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "claymore"
					URI = "https://tradeproject.de/download/Miner/TT-Miner-4.0.2.zip"
					Path = "$Name\TT-Miner.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $alg $hosts --nvidia -b 127.0.0.1:3360 -PRS 25 -PRT 24 -luck $extrargs"
					Port = 3360
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = 1
				}
			}
		}
	}
}
