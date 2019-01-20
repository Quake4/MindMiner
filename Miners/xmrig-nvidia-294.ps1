<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
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
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptolight"; ExtraArgs = "-a cryptonight-lite" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightheavy"; ExtraArgs = "-a cryptonight-heavy" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightv7"; ExtraArgs = "-a cryptonight" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightv8"; ExtraArgs = "-a cryptonight" }
)}

if (!$Cfg.Enabled) { return }

$file = [IO.Path]::Combine($BinLocation, $Name, "config.json")
if ([IO.File]::Exists($file)) {
	[IO.File]::Delete($file)
}

switch ([Config]::CudaVersion) {
	{ $_ -ge [version]::new(10, 0) } { $url = "https://github.com/xmrig/xmrig-nvidia/releases/download/v2.9.4/xmrig-nvidia-2.9.4-cuda10-win64.zip" }
	([version]::new(9, 2)) { $url = "https://github.com/xmrig/xmrig-nvidia/releases/download/v2.9.4/xmrig-nvidia-2.9.4-cuda9_2-win64.zip" }
	([version]::new(9, 1)) { $url = "https://github.com/xmrig/xmrig-nvidia/releases/download/v2.9.4/xmrig-nvidia-2.9.4-cuda9_1-win64.zip" }
	([version]::new(9, 0)) { $url = "https://github.com/xmrig/xmrig-nvidia/releases/download/v2.9.4/xmrig-nvidia-2.9.4-cuda9_0-win64.zip" }
	default { $url = "https://github.com/xmrig/xmrig-nvidia/releases/download/v2.9.4/xmrig-nvidia-2.9.4-cuda8-win64.zip" }
}

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$variant = "--variant 1"
				if ($_.Algorithm -eq "cryptonightv8") {
					$variant = "--variant 2"
				}
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "xmrig"
					URI = $url
					Path = "$Name\xmrig-nvidia.exe"
					ExtraArgs = $extrargs
					Arguments = "-o $($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) --api-port=4043 $variant --donate-level=1 -R $($Config.CheckTimeout) $extrargs"
					Port = 4043
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = 1
				}
			}
		}
	}
}
