<#
MindMiner  Copyright (C) 2018-2019  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if (![Config]::Is64Bit) { exit }
if ([Config]::CudaVersion -lt [version]::new(9, 2) -or [Config]::CudaVersion -gt [version]::new(10, 1)) { return }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 120
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "ethash" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "lyra2v3" } # dredge faster
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "tethashv1" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "mtp" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "mtp"; ExtraArgs = "-i 15" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "mtp"; ExtraArgs = "-gs 10240" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "progpow" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "progpow092" }
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
				$alg = $_.Algorithm.ToUpper()
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "claymore"
					URI = "https://tradeproject.de/download/Miner/TT-Miner-2.2.5.zip"
					Path = "$Name\TT-Miner.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $alg -o stratum+tcp://$($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -worker $([Config]::WorkerNamePlaceholder) --nvidia -b 127.0.0.1:3360 -PRS 25 -PRT 24 -luck $extrargs"
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