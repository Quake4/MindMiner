<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Include.ps1

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if ([Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $true
	BenchmarkSeconds = 60
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "bitcore" } # enemy faster
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "blake2s" } # only dual
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "blakecoin" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonight" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "c11" } # enemy faster
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "decred" }
		# not work [AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "groestl" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "hsr" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "hmq1725" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "jackpot" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "keccak"; ExtraArgs = "-i 27" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "keccakc" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lbry" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "lyra2v2"; } # alexis faster
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2z"; ExtraArgs = "-i 20.5" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "myr-gr" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "neoscrypt" } # klaust faster
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "nist5" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "phi"; } # phi faster
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "polytimos" }
		# not work [AlgoInfoEx]@{ Enabled = $true; Algorithm = "sia" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sib"; BenchmarkSeconds = 90 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sha256d" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sha256t" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "skein" } # klaust faster
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "skunk" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "timetravel" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "tribus"; BenchmarkSeconds = 90 }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "tribus"; ExtraArgs = "-i 24"; BenchmarkSeconds = 90 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "veltor" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x11evo" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x12" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x16r"; BenchmarkSeconds = 120 } # enemy faster
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x16s"; BenchmarkSeconds = 120 } # enemy faster
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x17"; BenchmarkSeconds = 120 } # enemy faster
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
					API = if ($Algo -match "x16.") { "ccminer_woe" } else { "ccminer" }
					URI = "https://github.com/tpruvot/ccminer/releases/download/2.2.5-tpruvot/ccminer-x86-2.2.5-cuda9.7z"
					Path = "$Name\ccminer.exe"
					ExtraArgs = $extrargs
					Arguments = "-q -a $($_.Algorithm) -o stratum+tcp://$($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -R $($Config.CheckTimeout) $N $extrargs"
					Port = 4068
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
				}
			}
		}
	}
}
