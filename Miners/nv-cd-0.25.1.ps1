<#
MindMiner  Copyright (C) 2018-2022  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if (![Config]::Is64Bit) { exit }
if ([Config]::CudaVersion -lt [version]::new(9, 2)) { return }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 180
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "aeternity" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "allium" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2d250" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2d4096" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2d4096"; ExtraArgs = "-i 7" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2d4096"; ExtraArgs = "-i 8" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2d-dyn" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "argon2d-nim" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "bcd" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "bitcore" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "chukwa" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "chukwa-wrkz" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cnconceal" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cnfast2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cngpu" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cnhaven" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cnheavy" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cnsaber" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cntlo" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cnturtle" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cnupx2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cnzls" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "cuckaroo29" } # fake speed and slower
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "hmq1725" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2v3" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2vc0ban" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2z" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2zz" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "mtp" } # unstable
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "mtp-tcr" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "neoscrypt" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "phi" } # phi faster
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "phi2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "phi2-lux" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "pipe" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "skunk" } # fastest
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "tribus" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x16r" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x16rt" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "veil" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x16rv2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x16s" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x17" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x21s" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x22i" }
)}

if (!$Cfg.Enabled) { return }

$url = "https://mindminer.online/miners/nVidia/cryptodredge-0.25.1-9.2.zip"
if ([Config]::CudaVersion -ge [version]::new(10, 2)) { $url = "https://mindminer.online/miners/nVidia/cryptodredge-0.25.1-10.2.zip" }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool -and ($Pool.Name -notmatch "nicehash" -or ($Pool.Name -match "nicehash" -and $_.Algorithm -notmatch "aeternity"))) {
				if ($_.Algorithm -match "veil") { $_.Algorithm = "x16rt" }
				elseif ($_.Algorithm -match "phi2-lux") { $_.Algorithm = "phi2" }
				elseif ($_.Algorithm -match "cnupx") { $_.Algorithm = "cnupx2" }
				$N = Get-CCMinerStatsAvg $Algo $_
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Priority = $Pool.Priority
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "ccminer"
					URI = $url
					Path = "$Name\cryptodredge.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) -o $($Pool.Protocol)://$($Pool.Hosts[0]):$($Pool.Port) -u $($Pool.User) -p $($Pool.Password) -R $($Config.CheckTimeout) -b 127.0.0.1:4068 --api-type ccminer-tcp --no-watchdog $N $extrargs"
					Port = 4068
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = if ($_.Algorithm -match "mtp") { 2 } else { 1 }
				}
			}
		}
	}
}