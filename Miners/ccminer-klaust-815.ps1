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
	# not validate on cpu [AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2v2" }
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
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "ccminer"
					URI = "https://github.com/KlausT/ccminer/releases/download/8.15/ccminer-815-cuda9-x64.zip"
					Path = "$Name\ccminer.exe"
					ExtraArgs = $_.ExtraArgs
					Arguments = "-a $($_.Algorithm) -o stratum+tcp://$($Pool.Host):$($Pool.Port) -u $($Pool.User) -p $($Pool.Password) $($_.ExtraArgs)"
					Port = 4068
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
				}
			}
		}
	}
}
