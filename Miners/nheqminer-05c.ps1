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
	[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash" }
	# [AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash"; ExtraArgs = "-i 15" }
)})

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				if (!($Pool.ByLogin -eq $true)) {
					# CPU
					for ([int] $i = [Config]::Processors; $i -le [Config]::Threads; $i++) {
						[MinerInfo]@{
							Pool = $Pool.PoolName()
							Name = $Name
							Algorithm = $Algo
							Type = [eMinerType]::CPU
							API = "nheq"
							URI = "https://github.com/nicehash/nheqminer/releases/download/0.5c/Windows_x64_nheqminer-5c.zip"
							Path = "$Name\nheqminer.exe"
							ExtraArgs = "-t $i $($_.ExtraArgs)"
							Arguments = "-l $($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -a 4100 -t $i $($_.ExtraArgs)"
							Port = 4100
							BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
						}
					}

					# nVidia
					<#[MinerInfo]@{
						Pool = $Pool.PoolName()
						Name = $Name
						Algorithm = $Algo
						Type = [eMinerType]::nVidia
						API = "nheq"
						URI = "https://github.com/nicehash/nheqminer/releases/download/0.5c/Windows_x64_nheqminer-5c.zip"
						Path = "$Name\nheqminer.exe"
						ExtraArgs = $_.ExtraArgs
						Arguments = "-l $($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -a 4101 -t 0 -cd $($_.ExtraArgs)"
						Port = 4101
						BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					}#>
				}
			}
		}
	}
}
