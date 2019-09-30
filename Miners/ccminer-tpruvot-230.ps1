<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if (![Config]::Is64Bit) { exit }
if ([Config]::CudaVersion -ge [version]::new(10, 0)) { return }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 60
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "allium"; ExtraArgs = "-i 21"; BenchmarkSeconds = 90 }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "bitcore" } # enemy faster
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "blake2s" } # only dual
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "blakecoin" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptolight" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonight" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "c11" } # enemy faster
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "decred" }
		# not work [AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "groestl" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "hsr" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "hmq1725" } # t-rex faster
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "jackpot" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "keccak"; ExtraArgs = "-i 27" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "keccakc" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lbry" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "lyra2v2"; } # alexis faster
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "lyra2z"; ExtraArgs = "-i 20.5" } # trex faster
		# [AlgoInfoEx]@{ Enabled = $true; Algorithm = "monero"; BenchmarkSeconds = 120 } # not work
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "myr-gr" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "neoscrypt" } # klaust faster
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "nist5" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "phi"; } # phi faster
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "phi2"; }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "phi2-lux"; }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "polytimos" }
		# not work [AlgoInfoEx]@{ Enabled = $true; Algorithm = "sia" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sib"; BenchmarkSeconds = 90 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sha256d" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sha256t" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "skein" } # klaust faster
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "skunk" } # dredge faster
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sonoa" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "timetravel" } # enemy faster
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "tribus"; BenchmarkSeconds = 90 }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "tribus"; ExtraArgs = "-i 24"; BenchmarkSeconds = 90 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "veltor" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x11evo" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x12" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x16r"; BenchmarkSeconds = 120 } # enemy faster
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x16s"; BenchmarkSeconds = 120 } # enemy faster
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x17"; BenchmarkSeconds = 120 } # enemy faster
)}

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				if ($_.Algorithm -match "phi2-lux") { $_.Algorithm = "phi2" }
				$N = Get-CCMinerStatsAvg $Algo $_
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "ccminer"
					URI = "https://github.com/tpruvot/ccminer/releases/download/2.3-tpruvot/ccminer-2.3-cuda9.7z"
					Path = "$Name\ccminer-x64.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) -o stratum+tcp://$($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -R $($Config.CheckTimeout) -q $N $extrargs"
					Port = 4068
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
				}
			}
		}
	}
}