<#
MindMiner  Copyright (C) 2017-2019  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $true
	BenchmarkSeconds = 60
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "blake2s" } # only dual
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "blakecoin" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "keccak" } # only dual
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lbry" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "lyra2v2"; BenchmarkSeconds = 120 } # dredge faster
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "myr-gr" }
		# [AlgoInfoEx]@{ Enabled = $true; Algorithm = "neoscrypt" } # klaust much faster
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "nist5" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sib" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sib"; ExtraArgs = "-i 21" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "skein" } # klaust faster
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "skein2" } # fastest
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "c11" } # enemy faster
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "c11"; ExtraArgs = "-i 21" } # enemy faster
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x17"; BenchmarkSeconds = 120 } # enemy faster
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "veltor" }
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
					API = "ccminer"
					URI = "https://github.com/Quake4/MindMinerPrerequisites/raw/master/nVidia/ccminer-alexis/ccminer-alexis-01.zip"
					Path = "$Name\ccminer.exe"
					ExtraArgs = $extrargs
					Arguments = "--cuda-schedule 3 -a $($_.Algorithm) -o stratum+tcp://$($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -R $($Config.CheckTimeout) -q $N $extrargs"
					Port = 4068
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
				}
			}
		}
	}
}
