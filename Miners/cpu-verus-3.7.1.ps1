<#
MindMiner  Copyright (C) 2017-2021  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::CPU) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$from = ($Devices[[eMinerType]::CPU] | Measure-Object Cores -Sum).Sum
$to = ($Devices[[eMinerType]::CPU] | Measure-Object Threads -Sum).Sum
if ([Config]::DefaultCPU) {
	$from = [Config]::DefaultCPU.Cores
	$to = [Config]::DefaultCPU.Threads
}
$Algorithms = @()
for ($t = $from; $t -le $to; $t++) {
	$Algorithms += [AlgoInfoEx]@{ Enabled = $true; Algorithm = "verus"; ExtraArgs = "-t $t" }
}

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 60
	ExtraArgs = $null
	Algorithms = $Algorithms
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
				if ($extrargs -notmatch "-t ") {
					$extrargs = Get-Join " " @($extrargs, "-t $($Devices["CPU"].Threads)")
				}
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Priority = $Pool.Priority
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::CPU
					API = "ccminer_woe"
					URI = "https://github.com/monkins1010/ccminer/releases/download/v3.7.0/ccminer3.7.1.exe"
					Path = "$Name\ccminer3.7.1.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) -o stratum+tcp://$($Pool.Hosts[0]):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -R $($Config.CheckTimeout) -q --cpu-priority 1 -b 4048 $N $extrargs"
					Port = 4048
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
				}
			}
		}
	}
}