<#
MindMiner  Copyright (C) 2018-2020  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if (![Config]::Is64Bit) { exit }
if ([Config]::CudaVersion -lt [version]::new(9, 2)) { return }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 90
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "astralhash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "jeonghash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "padihash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "pawelhash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "balloon"; BenchmarkSeconds = 120 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "bcd" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "bitcore" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "c11" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "dedal" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "etchash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "ethash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "geek" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "hmq1725" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "honeycomb" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "hsr" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "kawpow"; BenchmarkSeconds = 120 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "kawpow"; BenchmarkSeconds = 120; ExtraArgs = "--low-load 1" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "lyra2z" } # dredge faster
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "megabtx" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "mtp" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "octopus" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "phi" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "progpow" } # isnt progpow bci
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "progpow-veil" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "progpow-veriblock" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "progpowz" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "polytimos" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sha256t" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sha256q" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "skunk" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sonoa" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "tensority" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "timetravel" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "tribus"; BenchmarkSeconds = 120 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x16r"; BenchmarkSeconds = 120 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x16rt"; BenchmarkSeconds = 120 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x16rv2"; BenchmarkSeconds = 120 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "veil"; BenchmarkSeconds = 120 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x16s"; BenchmarkSeconds = 120 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x17"; BenchmarkSeconds = 120 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x21s"; BenchmarkSeconds = 120 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x22i"; BenchmarkSeconds = 120 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x25x"; BenchmarkSeconds = 120 }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x33"; BenchmarkSeconds = 120 }
)}

if (!$Cfg.Enabled) { return }

switch ([Config]::CudaVersion) {
	{ $_ -ge [version]::new(11, 1) } { $url = "https://github.com/trexminer/T-Rex/releases/download/0.19.5/t-rex-0.19.5-win-cuda11.1.zip" }
	{ $_ -ge [version]::new(10, 0) } { $url = "https://github.com/trexminer/T-Rex/releases/download/0.19.5/t-rex-0.19.5-win-cuda10.0.zip" }
	default { $url = "https://github.com/trexminer/T-Rex/releases/download/0.19.5/t-rex-0.19.5-win-cuda9.2.zip" }
}

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$fee = 1
				if ($_.Algorithm -eq "veil") { $_.Algorithm = "x16rt" }
				elseif ($_.Algorithm -match "tensority") { $fee = 3 }
				$BenchSecs = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
				$N = "-N $([Convert]::ToInt32($BenchSecs))"
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				$hosts = [string]::Empty
				$stratum = "stratum"
				if ($_.Algorithm -match "ethash") {
					if ($Pool.Name -match "nicehash") { $stratum = "nicehash" }
					elseif ($Pool.Name -match "mph") { $stratum = "stratum2" }
				}
				$Pool.Hosts | ForEach-Object {
					$hosts = Get-Join " " @($hosts, "-o $stratum+tcp://$_`:$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password)")
				}
				$hosts += " -w $([Config]::WorkerNamePlaceholder)"
				# if ($extrargs -notmatch "--gpu-report-interval") {
				# 	$hosts = Get-Join " " @($hosts, "--gpu-report-interval 50")
				# }
				if ($_.Algorithm -match "octopus") { $fee = 2 }
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Priority = $Pool.Priority
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "ccminer_woe"
					URI = $url
					Path = "$Name\t-rex.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) $hosts -R $($Config.CheckTimeout) -b 127.0.0.1:4068 --no-watchdog --gpu-report-interval 60 $N $extrargs"
					Port = 4068
					BenchmarkSeconds = $BenchSecs
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = $fee
				}
			}
		}
	}
}