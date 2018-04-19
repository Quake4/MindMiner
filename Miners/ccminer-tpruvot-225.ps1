<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $true
	BenchmarkSeconds = 60
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "bitcore" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "blake2s" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "blakecoin" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonight" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "c11" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "decred" }
		# not work [AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "groestl" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "hsr" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "hmq1725" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "jackpot" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "keccak" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "keccakc" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lbry" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "lyra2v2"; } # alexis faster
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2z" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "myr-gr" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "neoscrypt" } # klaust faster
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "nist5" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "phi"; } # phi faster
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "polytimos" }
		# not work [AlgoInfoEx]@{ Enabled = $true; Algorithm = "sia" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sib" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "skein" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "skunk" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "timetravel" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "tribus"; BenchmarkSeconds = 90 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "tribus"; ExtraArgs = "-i 24"; BenchmarkSeconds = 90 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "veltor" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x11evo" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x12" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x16r"; BenchmarkSeconds = 120 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x16s"; BenchmarkSeconds = 120 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x17"; BenchmarkSeconds = 120 }
)})

if (!$Cfg.Enabled) { return }

if ([Config]::Is64Bit -eq $true) {
	$url = "https://github.com/tpruvot/ccminer/releases/download/2.2.5-tpruvot/ccminer-x64-2.2.5-cuda9.7z"
	$file = "ccminer-x64.exe"
}
else {
	$url = "https://github.com/tpruvot/ccminer/releases/download/2.2.5-tpruvot/ccminer-x86-2.2.5-cuda9.7z"
	$file = "ccminer.exe"
}

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$N = Get-CCMinerStatsAvg $Algo $_
				$pass = Get-PasswordString $Algo $Pool.Password
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = if ($Algo -match "x16.") { "ccminer_woe" } else { "ccminer" }
					URI = $url
					Path = "$Name\$file"
					ExtraArgs = $_.ExtraArgs
					Arguments = "-a $($_.Algorithm) -o stratum+tcp://$($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $pass -R $($Config.CheckTimeout) $N $($_.ExtraArgs)"
					Port = 4068
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
				}
			}
		}
	}
}
