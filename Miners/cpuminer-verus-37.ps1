<#
MindMiner  Copyright (C) 2017-2020  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::CPU) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$algos = @()
for ([int] $i = $Devices["CPU"].Cores; $i -le $Devices["CPU"].Threads; $i++) {
	$algos += [AlgoInfoEx]@{ Enabled = $true; Algorithm = "verus"; ExtraArgs = "-t $i" }
}

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 180
	ExtraArgs = $null
	Algorithms = $algos
}

if (!$Cfg.Enabled) { return }

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
					Priority = $Pool.Priority
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::CPU
					API = "ccminer_woe"
					URI = "http://mindminer.online/miners/CPU/cpuminer-verus-37.zip"
					Path = "$Name\ccminer.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) -o stratum+tcp://$($Pool.Hosts[0]):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -R $($Config.CheckTimeout) -q --cpu-priority 1 -b 4048 -t $($Devices["CPU"].Cores) $N $extrargs"
					Port = 4048
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
				}
			}
		}
	}
}