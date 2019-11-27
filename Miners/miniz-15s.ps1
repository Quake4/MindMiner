<#
MindMiner  Copyright (C) 2019  Oleg Samsonov aka Quake4
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
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "aion" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "aion"; ExtraArgs = "--oc1" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "aion"; ExtraArgs = "--oc2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "beam" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "beam"; ExtraArgs = "--oc1" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "beam"; ExtraArgs = "--oc2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "beamV2" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "beamV2"; ExtraArgs = "--oc1" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "beamV2"; ExtraArgs = "--oc2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash125" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihash125"; ExtraArgs = "--oc1" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihash125"; ExtraArgs = "--oc2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash144" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihash144"; ExtraArgs = "--oc1" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihash144"; ExtraArgs = "--oc2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash192" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihash192"; ExtraArgs = "--oc1" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihash192"; ExtraArgs = "--oc2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihashZCL" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihashZCL"; ExtraArgs = "--oc1" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihashZCL"; ExtraArgs = "--oc2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash96" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihash96"; ExtraArgs = "--oc1" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihash96"; ExtraArgs = "--oc2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihashBTG" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihashBTG"; ExtraArgs = "--oc1" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihashBTG"; ExtraArgs = "--oc2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "zhash" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "zhash"; ExtraArgs = "--oc1" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "zhash"; ExtraArgs = "--oc2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "zelcash" }
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
			if ($Pool) {
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				$alg = [string]::Empty
				switch ($_.Algorithm) {
					"aion" { $alg = "--par=210,9" }
					"beam" { $alg = "--par=150,5" }
					"beamV2" { $alg = "--par=150,5,3" }
					"equihash125" { $alg = "--par=125,4" }
					"equihash144" { $alg = "--par=144,5" }
					"equihash192" { $alg = "--par=192,7" }
					"equihashZCL" { $alg = "--par=192,7 --pers=ZcashPoW" }
					"equihash96" { $alg = "--par=96,5" }
					"equihashBTG" { $alg = "--par=144,5 --pers=BgoldPoW" }
					"zhash" { $alg = "--par=144,5" }
					"zelcash" { $alg = "--par=125,4" }
				}
				if (!($extrargs -match "-pers" -or $alg -match "-pers")) {
					$alg = Get-Join " " @($alg, "--pers=auto")
				}
				$user = $Pool.User
				if ($user -notmatch ".$([Config]::WorkerNamePlaceholder)") {
					$user = "$user._"
				}
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Priority = $Pool.Priority
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "ewbf"
					URI = "http://mindminer.online/miners/nVidia/miniz-15s-10.zip"
					Path = "$Name\miniz.exe"
					ExtraArgs = $extrargs
					Arguments = "$alg --url=$user@$($Pool.Hosts[0]):$($Pool.PortUnsecure) -p $($Pool.Password) -a 42000 --nocolor --latency --show-shares $extrargs"
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