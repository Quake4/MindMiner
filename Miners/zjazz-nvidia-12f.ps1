<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $true
	BenchmarkSeconds = 120
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "bitcash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "bitcash"; ExtraArgs="--cuckoo-intensity 16" } # 3Gb
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "bitcash"; ExtraArgs="--cuckoo-intensity 18" } # 4Gb
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "bitcash"; ExtraArgs="--cuckoo-intensity 22" } # 8Gb
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x22i" }
)})

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = if ($_.Algorithm -match "x22i") { "ccminer" } else { "zjazz_cuckoo" }
					URI = "https://github.com/zjazz/zjazz_cuda_miner/releases/download/1.2/zjazz_cuda_win64_1.2.zip"
					Path = "$Name\zjazz_cuda.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) -o stratum+tcp://$($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -R $($Config.CheckTimeout) -T 60 -b 127.0.0.1:4068 --hide-hashrate-per-gpu --disable-restart-on-gpu-error $extrargs"
					Port = 4068
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = 2
				}
			}
		}
	}
}