<#
MindMiner  Copyright (C) 2018-2020  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::AMD) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 120
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2/wrkz" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cn/ccx" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cn/r" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cn-heavy/tube" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "kawpow" }
		[AlgoInfoEx]@{ Enabled = $([Config]::ActiveTypes -notcontains [eMinerType]::CPU); Algorithm = "rx/0" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "rx/arq" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "rx/keva" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "rx/loki" }
		[AlgoInfoEx]@{ Enabled = $([Config]::ActiveTypes -notcontains [eMinerType]::CPU); Algorithm = "rx/sfx" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "rx/wow" }
)}

if (!$Cfg.Enabled) { return }

$file = [IO.Path]::Combine($BinLocation, $Name, "config.json")
if ([IO.File]::Exists($file)) {
	[IO.File]::Delete($file)
}

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo -and $Algo -notmatch "chukwa") {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				$pools = [string]::Empty
				$Pool.Hosts | ForEach-Object {
					$pools = Get-Join " " @($pools, "-o $_`:$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password)")
				}
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Priority = $Pool.Priority
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::AMD
					API = "xmrig2"
					URI = "https://github.com/xmrig/xmrig/releases/download/v6.2.2/xmrig-6.2.2-gcc-win64.zip"
					Path = "$Name\xmrig.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) $pools -R $($Config.CheckTimeout) --http-port=4044 --donate-level=1 --no-cpu --opencl --opencl-platform=$([Config]::AMDPlatformId) $extrargs"
					Port = 4044
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = 1
				}
			}
		}
	}
}