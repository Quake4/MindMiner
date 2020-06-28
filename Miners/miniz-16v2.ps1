<#
MindMiner  Copyright (C) 2019-2020  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if (![Config]::Is64Bit) { exit }
if ([Config]::CudaVersion -lt [version]::new(10, 0)) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $true
	BenchmarkSeconds = 90
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "beam" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "beam"; ExtraArgs = "--ocX"; BenchmarkSeconds = 180 }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "beam"; ExtraArgs = "--oc1" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "beam"; ExtraArgs = "--oc2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "beamV2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "beamV2"; ExtraArgs = "--ocX"; BenchmarkSeconds = 180 }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "beamV2"; ExtraArgs = "--oc1" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "beamV2"; ExtraArgs = "--oc2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "beamV3" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "beamV3"; ExtraArgs = "--ocX"; BenchmarkSeconds = 180 }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "beamV3"; ExtraArgs = "--oc1" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "beamV3"; ExtraArgs = "--oc2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash125" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash125"; ExtraArgs = "--ocX"; BenchmarkSeconds = 180 }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihash125"; ExtraArgs = "--oc1" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihash125"; ExtraArgs = "--oc2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash144" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash144"; ExtraArgs = "--ocX"; BenchmarkSeconds = 180 }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihash144"; ExtraArgs = "--oc1" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihash144"; ExtraArgs = "--oc2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash192" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash192"; ExtraArgs = "--ocX"; BenchmarkSeconds = 180 }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihash192"; ExtraArgs = "--oc1" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihash192"; ExtraArgs = "--oc2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihashZCL" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihashZCL"; ExtraArgs = "--ocX"; BenchmarkSeconds = 180 }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihashZCL"; ExtraArgs = "--oc1" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihashZCL"; ExtraArgs = "--oc2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash210" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash210"; ExtraArgs = "--ocX"; BenchmarkSeconds = 180 }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihash210"; ExtraArgs = "--oc1" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihash210"; ExtraArgs = "--oc2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash96" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash96"; ExtraArgs = "--ocX"; BenchmarkSeconds = 180 }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihash96"; ExtraArgs = "--oc1" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihash96"; ExtraArgs = "--oc2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihashBTG" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihashBTG"; ExtraArgs = "--ocX"; BenchmarkSeconds = 180 }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihashBTG"; ExtraArgs = "--oc1" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihashBTG"; ExtraArgs = "--oc2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "zhash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "zhash"; ExtraArgs = "--ocX"; BenchmarkSeconds = 180 }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "zhash"; ExtraArgs = "--oc1" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "zhash"; ExtraArgs = "--oc2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "zelcash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "zelcash"; ExtraArgs = "--ocX"; BenchmarkSeconds = 180 }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "zelcash"; ExtraArgs = "--oc1" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "zelcash"; ExtraArgs = "--oc2" }
)})

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool -and ($Pool.Name -notmatch "mrr" -or ($Pool.Name -match "mrr" -and $_.Algorithm -notmatch "beam"))) {
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				$alg = [string]::Empty
				switch ($_.Algorithm) {
					"beam" { $alg = "--par=150,5" }
					"beamV2" { $alg = "--par=150,5,3" }
					"beamV3" { $alg = "--par=beam3" }
					"equihash125" { $alg = "--par=125,4" }
					"equihash144" { $alg = "--par=144,5" }
					"equihash192" { $alg = "--par=192,7" }
					"equihashZCL" { $alg = "--par=192,7 --pers=ZcashPoW" }
					"equihash210" { $alg = "--par=210,9" }
					"equihash96" { $alg = "--par=96,5" }
					"equihashBTG" { $alg = "--par=144,5 --pers=BgoldPoW" }
					"zhash" { $alg = "--par=144,5" }
					"zelcash" { $alg = "--par=125,4" }
				}
				if (!($extrargs -match "-pers" -or $alg -match "-pers")) {
					$alg = Get-Join " " @($alg, "--pers=auto")
				}
				$user = $Pool.User
				if ($user -notmatch ".$([Config]::WorkerNamePlaceholder)" -and !$user.Contains(".")) {
					$user = "$user._"
				}
				$pools = [string]::Empty
				$Pool.Hosts | ForEach-Object {
					$pools = Get-Join " " @($pools, "--url=$user@$_`:$($Pool.PortUnsecure) -p $($Pool.Password)")
				}
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Priority = $Pool.Priority
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "ewbf"
					URI = "http://mindminer.online/miners/nVidia/miniz-16v2.zip"
					Path = "$Name\miniz.exe"
					ExtraArgs = $extrargs
					Arguments = "$alg $pools -a 42000 --latency --show-shares --stat-int=60 $extrargs"
					Port = 42000
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = 2
				}
			}
		}
	}
}