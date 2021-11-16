<#
MindMiner  Copyright (C) 2018-2021  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::CPU) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$extraThreads = $null
$extraCores = $null
if ([Config]::DefaultCPU) {
	$extraThreads = "-t $([Config]::DefaultCPU.Threads)"
	$extraCores = "-t $([Config]::DefaultCPU.Cores)"
}

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 120
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "argon2/chukwa" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2/chukwav2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2/wrkz" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cn/ccx"; ExtraArgs = $extraCores }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cn/r" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cn/rwz" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cn/zls" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cn-heavy/tube" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cn-heavy/xhv" } # L3 limit
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cn/upx2"; ExtraArgs = $extraThreads }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "rx/0"; ExtraArgs = $extraThreads }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "rx/arq"; ExtraArgs = $extraThreads }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "rx/graft" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "rx/keva" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "rx/sfx"; ExtraArgs = $extraCores }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "rx/wow"; ExtraArgs = $extraThreads }
		
)}

if (!$Cfg.Enabled) { return }

$file = [IO.Path]::Combine($BinLocation, $Name, "config.json")
if ([IO.File]::Exists($file)) {
	[IO.File]::Delete($file)
}

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
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
					Type = [eMinerType]::CPU
					API = "xmrig2"
					URI = "https://github.com/xmrig/xmrig/releases/download/v6.15.3/xmrig-6.15.3-gcc-win64.zip"
					Path = "$Name\xmrig.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) $pools -R $($Config.CheckTimeout) --http-port=4045 --donate-level=1 --no-dmi --cpu-priority 0 $extrargs"
					Port = 4045
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = 1
				}
			}
		}
	}
}