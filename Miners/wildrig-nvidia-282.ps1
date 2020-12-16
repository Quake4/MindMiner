<#
MindMiner  Copyright (C) 2018-2020  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 120
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "aergo" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "anime" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "bcd" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "bitcore" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "blake2b-btcc" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "blake2b-glt" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "bmw512" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "c11" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "dedal" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "exosis" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "geek" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "glt-astralhash" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "glt-globalhash" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "glt-hex" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "glt-jeonghash" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "glt-padihash" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "glt-pawelhash" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "hex" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "hmq1725" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "honeycomb" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "kawpow" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2tdc" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2v3" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2vc0ban" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "mtp" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "mtp-tcr" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "megabtx" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "megamec" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "minotaur" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "phi" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "polytimos" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "progpow-ethercore" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "progpow-sero" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "progpow-veil" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "progpowz" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "vprogpow" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "renesis" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sha256q" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sha256t" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sha256csm" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "skein2" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "skunkhash" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "sonoa" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "timetravel" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "tribus" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "wildkeccak" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x11k" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x16r" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x16rv2" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x16rt" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "veil" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x16s" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x17" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x17r" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x18" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x20r" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x21s" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x33" }
		# [AlgoInfoEx]@{ Enabled = $true; Algorithm = "x22i" } # not even work
		# [AlgoInfoEx]@{ Enabled = $true; Algorithm = "x25x" } # not even work
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "xevan" }
)}

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				if ($_.Algorithm -eq "veil") { $_.Algorithm = "x16rt" }
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				$hosts = [string]::Empty
				$Pool.Hosts | ForEach-Object {
					$hosts = Get-Join " " @($hosts, "-o $_`:$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password)")
				}
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Priority = $Pool.Priority
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					TypeInKey = $true
					API = "xmrig"
					URI = "https://github.com/andru-kun/wildrig-multi/releases/download/0.28.2/wildrig-multi-windows-0.28.2.7z"
					Path = "$Name\wildrig.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) $hosts -R $($Config.CheckTimeout) --opencl-platform=$([Config]::nVidiaPlatformId) --no-adl --api-port=4068 --donate-level=1 $extrargs"
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