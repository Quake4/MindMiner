<#
MindMiner  Copyright (C) 2018-2022  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if (![Config]::Is64Bit) { exit }
if ([Config]::CudaVersion -lt [version]::new(9, 2)) { return }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 90
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "autolykos2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "blake3" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "etchash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "ethash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "firopow"; BenchmarkSeconds = 120 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "kawpow"; BenchmarkSeconds = 120 }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "kawpow"; BenchmarkSeconds = 120; ExtraArgs = "--low-load 1" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "mtp" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "mtp-tcr" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "multi" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "octopus" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "progpow" } # isnt progpow bci
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "progpow-veil" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "progpow-veriblock" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "progpowz" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "tensority" }
)}

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$fee = 1
				if ($_.Algorithm -eq "veil") { $_.Algorithm = "x16rt" }
				elseif ($_.Algorithm -match "tensority") { $fee = 3 }
				elseif ($_.Algorithm -match "autolykos2") { $fee = 2 }
				$BenchSecs = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
				$N = "-N $([Convert]::ToInt32($BenchSecs))"
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				$hosts = [string]::Empty
				$stratum = "stratum"
				if ($_.Algorithm -match "ethash") {
					if ($Pool.Name -match "nicehash") { $stratum = "nicehash" }
					elseif ($Pool.Name -match "mph") { $stratum = "stratum2" }
				}
				if ($Pool.Protocol -match "ssl") { $stratum += "+ssl" } else { $stratum += "+tcp" }
				$Pool.Hosts | ForEach-Object {
					$hosts = Get-Join " " @($hosts, "-o $stratum`://$_`:$($Pool.Port) -u $($Pool.User) -p $($Pool.Password)")
				}
				$hosts += " -w $([Config]::WorkerNamePlaceholder)"
				if ($_.Algorithm -match "octopus") { $fee = 2 }
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Priority = $Pool.Priority
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "trex"
					URI = "https://trex-miner.com/download/t-rex-0.25.9-win.zip"
					Path = "$Name\t-rex.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) $hosts -R $($Config.CheckTimeout) --api-bind-http 127.0.0.1:4068 --api-read-only --no-strict-ssl --no-watchdog --gpu-report-interval 60 $N $extrargs"
					Port = 4068
					BenchmarkSeconds = $BenchSecs
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = $fee
				}
			}
		}
	}
}