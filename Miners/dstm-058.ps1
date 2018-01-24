<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
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
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash" }
	#[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash"; ExtraArgs = "--solver 0" }
)})

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)

			$proto = [string]::Empty
			if ($Pool.Protocol -contains "ssl") {
				$proto = "ssl://"
			}

			if ($Pool) {
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "dstm"
					URI = "https://github.com/Quake4/MindMinerPrerequisites/raw/master/nVidia/dstm/zm_0.5.8_win.zip"
					Path = "$Name\zm.exe"
					ExtraArgs = $_.ExtraArgs
					Arguments = "--server $proto$($Pool.Host) --port $($Pool.Port) --user $($Pool.User) --pass $($Pool.Password) --time --telemetry=127.0.0.1:2222 $($_.ExtraArgs)"
					Port = 2222
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					Fee = 2
				}
			}
		}
	}
}