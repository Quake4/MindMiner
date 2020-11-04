<#
MindMiner  Copyright (C) 2017-2020  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Algs = @()
if ([Config]::nVidiaDevices -gt 0) {
	$devs = @()
	for ($i = 0; $i -lt [Config]::nVidiaDevices; $i++) {
		$devs += $i.ToString()
	}
	$devstring = "-d " + (Get-Join "," $devs)
	$Algs += [AlgoInfoEx]@{ Enabled = $true; Algorithm = "verus"; ExtraArgs = "$devstring" }
	$Algs += [AlgoInfoEx]@{ Enabled = $true; Algorithm = "verus"; ExtraArgs = "-i 22 $devstring" }
}
else {
	$Algs = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "verus" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "verus"; ExtraArgs = "-i 22" }
	)
}

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 120
	ExtraArgs = $null
	Algorithms = $Algs
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
					Type = [eMinerType]::nVidia
					API = "ccminer"
					URI = "http://mindminer.online/miners/nVidia/ccminer-verus-38.zip"
					Path = "$Name\ccminer.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) -o stratum+tcp://$($Pool.Hosts[0]):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -R $($Config.CheckTimeout) -q $N $extrargs"
					Port = 4068
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					# fix real speed lower than reported (6.35 => 5.75)
					Fee = 10
				}
			}
		}
	}
}