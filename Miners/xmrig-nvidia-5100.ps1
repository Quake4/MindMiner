<#
MindMiner  Copyright (C) 2018-2020  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if (![Config]::Is64Bit) { exit }
if ([Config]::CudaVersion -lt [version]::new(10, 1)) { return }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 90
	ExtraArgs = $null
	Algorithms = @(
		# [AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2/chukwa" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2/wrkz" }
		[AlgoInfoEx]@{ Enabled = $([Config]::ActiveTypes -notcontains [eMinerType]::CPU); Algorithm = "rx/0" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "rx/arq" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "rx/keva" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "rx/loki" }
		[AlgoInfoEx]@{ Enabled = $([Config]::ActiveTypes -notcontains [eMinerType]::CPU); Algorithm = "rx/sfx" }
		# [AlgoInfoEx]@{ Enabled = $false; Algorithm = "rx/v" } # removed
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "rx/wow" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cn/r" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cn/gpu" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cn-heavy/tube" }
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
					Type = [eMinerType]::nVidia
					API = "xmrig2"
					URI = "https://github.com/xmrig/xmrig/releases/download/v5.10.0/xmrig-5.10.0-msvc-cuda10_1-win64.zip"
					Path = "$Name\xmrig.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) $pools -R $($Config.CheckTimeout) --http-port=4043 --donate-level=1 --no-cpu --cuda --no-nvml $extrargs"
					Port = 4043
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = 1
				}
			}
		}
	}
}
