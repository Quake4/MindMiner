<#
MindMiner  Copyright (C) 2017-2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 60
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "blakecoin" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "c11"; ExtraArgs = "-i 21" } # enemy faster
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "groestl" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "jackpot" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "keccak" } # only dual
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "lyra2v2" } # alexis faster
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "myr-gr" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "neoscrypt" } # auto # dredge faster
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "neoscrypt"; ExtraArgs = "-i 16" } # GTX1060/6Gb
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "neoscrypt"; ExtraArgs = "-i 17" } # GTX1070
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "neoscrypt"; ExtraArgs = "-i 18" } # GTX1080
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "neoscrypt"; ExtraArgs = "-i 19" } # GTX1080Ti
		# not work [AlgoInfoEx]@{ Enabled = $true; Algorithm = "nist5" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "skein" }
)}

if (!$Cfg.Enabled) { return }

$url = "https://github.com/KlausT/ccminer/releases/download/8.23/ccminer-823-cuda92-x64.zip";
if ([Config]::CudaVersion -ge [version]::new(10, 0)) {
	$url = "https://github.com/KlausT/ccminer/releases/download/8.23/ccminer-823-cuda10-x64.zip"
}

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
					URI = $url
					Path = "$Name\ccminer.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) -o stratum+tcp://$($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -R $($Config.CheckTimeout) -q -b 4068 $N $extrargs"
					Port = 4068
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
				}
			}
		}
	}
}