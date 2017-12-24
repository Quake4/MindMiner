<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $true
	BenchmarkSeconds = 90
	Algorithms = @(
		# not work [AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonight"; ExtraArgs="--rawintensity 512 -w 4 -g 2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "decred"; ExtraArgs="-X 256 --lookup-gap 2 -w 64 -g 1" }
		# not work [AlgoInfoEx]@{ Enabled = $true; Algorithm = "ethash"; ExtraArgs="-X 512 -w 192 -g 1" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "keccak"; ExtraArgs="-I 15" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lbry"; ExtraArgs="-I 20 -g 2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2rev2"; ExtraArgs="-X 160 -w 64 -g 1" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2rev2"; ExtraArgs="-X 160 --thread-concurrency 0 -w 64 -g 1" }
		# not work [AlgoInfoEx]@{ Enabled = $true; Algorithm = "neoscrypt"; ExtraArgs="-X 2 -w 64 -g 4" }
		# not work [AlgoInfoEx]@{ Enabled = $true; Algorithm = "neoscrypt"; ExtraArgs="-X 2 --thread-concurrency 8192 -w 64 -g 4" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "pascal"; ExtraArgs="-I 21 -w 64 -g 2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sibcoin-mod"; ExtraArgs="-I 16 -g 2" } #570
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sibcoin-mod"; ExtraArgs="-I 16 -g 4" } #580
	)
})

if (!$Cfg.Enabled) { return }

if ([Config]::Is64Bit -eq $true) {
	$url = "https://github.com/nicehash/sgminer/releases/download/5.6.1/sgminer-5.6.1-nicehash-51-windows-amd64.zip"
}
else {
	$url = "https://github.com/nicehash/sgminer/releases/download/5.6.1/sgminer-5.6.1-nicehash-51-windows-i386.zip"
}

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::AMD
					API = "sgminer"
					URI = $url
					Path = "$Name\sgminer.exe"
					ExtraArgs = $_.ExtraArgs
					Arguments = "-k $($_.Algorithm) -o stratum+tcp://$($Pool.Host):$($Pool.Port) -u $($Pool.User) -p $($Pool.Password) --api-listen --gpu-platform $([Config]::AMDPlatformId) $($_.ExtraArgs)"
					Port = 4028
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
				}
			}
		}
	}
}