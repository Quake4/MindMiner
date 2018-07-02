<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Include.ps1

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $true
	BenchmarkSeconds = 90
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "allium" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "blake2s" } # only dual
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2v2"; BenchmarkSeconds = 120 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2z" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "neoscrypt" } # klaust faster
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "phi" } # phi faster
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "phi2" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "skein" } # not work
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "skunk" } # tpruvot faster
)})

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
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "dredge"
					URI = "https://github.com/technobyl/CryptoDredge/releases/download/v0.6.0/CryptoDredge_0.6.0.zip"
					Path = "$Name\cryptodredge.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) -o stratum+tcp://$($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -b 127.0.0.1:4068 --api-type ccminer-tcp --no-watchdog -R $($Config.CheckTimeout) $N $extrargs"
					Port = 4068
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = 1
				}
			}
		}
	}
}