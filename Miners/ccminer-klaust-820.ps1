<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Include.ps1

if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $true
	BenchmarkSeconds = 60
	Algorithms = @(
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "blakecoin" }
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "c11" }
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "groestl" }
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "jackpot" }
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "keccak" }
	[AlgoInfoEx]@{ Enabled = $false; Algorithm = "lyra2v2" } # alexis faster
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "myr-gr" }
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "neoscrypt" } # auto
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "neoscrypt"; ExtraArgs = "-i 15" } # GTX1060/3Gb
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "neoscrypt"; ExtraArgs = "-i 16" } # GTX1060/6Gb
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "neoscrypt"; ExtraArgs = "-i 17" } # GTX1070
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "neoscrypt"; ExtraArgs = "-i 18" } # GTX1080
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "neoscrypt"; ExtraArgs = "-i 19" } # GTX1080Ti
	# not work [AlgoInfoEx]@{ Enabled = $true; Algorithm = "nist5" }
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "skein" }
)})

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$N = Get-CCMinerStatsAvg($Algo, $_)
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "ccminer"
					URI = "https://github.com/KlausT/ccminer/releases/download/8.20/ccminer-820-cuda91-x64.zip"
					Path = "$Name\ccminer.exe"
					ExtraArgs = $_.ExtraArgs
					Arguments = "-a $($_.Algorithm) -o stratum+tcp://$($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -R 5 -b 4068 $N $($_.ExtraArgs)"
					Port = 4068
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
				}
			}
		}
	}
}
