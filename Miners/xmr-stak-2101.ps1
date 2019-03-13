<#
MindMiner  Copyright (C) 2017-2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if (![Config]::Is64Bit) { exit }
if ([Environment]::OSVersion.Version -lt [Version]::new(10, 0)) { exit }

function Save-BaseConfig([string] $path) {
	$nl = [Environment]::NewLine
	"`"call_timeout`" : 10," + $nl +
	"`"retry_time`" : $($Config.CheckTimeout)," + $nl +
	"`"giveup_limit`" : 0," + $nl +
	"`"verbose_level`" : 3," + $nl +
	"`"print_motd`" : true," + $nl +
	"`"h_print_time`" : 60," + $nl +
	"`"aes_override`" : null," + $nl +
	"`"use_slow_memory`" : `"warn`"," + $nl +
	"`"tls_secure_algo`" : true," + $nl +
	"`"daemon_mode`" : false," + $nl +
	"`"flush_stdout`" : false," + $nl +
	"`"output_file`" : `"`"," + $nl +
	"`"httpd_port`" : 9999," + $nl +
	"`"http_login`" : `"`"," + $nl +
	"`"http_pass`" : `"`"," + $nl +
	"`"prefer_ipv4`" : true," + $nl |
	Out-File "$path\config.txt" -Force -Encoding ascii
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Dir = [IO.Path]::Combine([Config]::BinLocation, $Name)
if (!(Test-Path $Dir)) {
	New-Item -ItemType Directory $Dir | Out-Null
}

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 90
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "cryptonight_heavy" } # jce+xmrig faster
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonight_v8" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonight_gpu" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonight_r" }
)}

if (!$Cfg.Enabled) { return }

Remove-Item "$Dir\cpu.txt" -Force -ErrorAction SilentlyContinue
Remove-Item "$Dir\amd.txt" -Force -ErrorAction SilentlyContinue
Remove-Item "$Dir\nvidia.txt" -Force -ErrorAction SilentlyContinue
Remove-Item "$Dir\pools.txt" -Force -ErrorAction SilentlyContinue
Save-BaseConfig $Dir

$url = "https://github.com/fireice-uk/xmr-stak/releases/download/2.10.1/xmr-stak-win64-2.10.1.7z"

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$usenicehash = [string]::Empty
				if ($Pool.Name -contains "nicehash") {
					$usenicehash = "--use-nicehash"
				}
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::CPU
					TypeInKey = $true
					API = "xmr-stak"
					URI = $url
					Path = "$Name\xmr-stak.exe"
					ExtraArgs = $extrargs
					Arguments = "--currency $($_.Algorithm) -o $($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -r --noUAC --noAMD --noNVIDIA $usenicehash -i 9995 $extrargs"
					Port = 9995
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = 2
				}
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::AMD
					TypeInKey = $true
					API = "xmr-stak"
					URI = $url
					Path = "$Name\xmr-stak.exe"
					ExtraArgs = $extrargs
					Arguments = "--currency $($_.Algorithm) -o $($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -r --noUAC --noCPU --noNVIDIA $usenicehash -i 9994 $extrargs"
					Port = 9994
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = 2
				}
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					TypeInKey = $true
					API = "xmr-stak"
					URI = $url
					Path = "$Name\xmr-stak.exe"
					ExtraArgs = $extrargs
					Arguments = "--currency $($_.Algorithm) -o $($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -r --noUAC --noCPU --noAMD $usenicehash -i 9993 $extrargs"
					Port = 9993
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = 2
				}
			}
		}
	}
}

<#
function Get-XMRStak([Parameter(Mandatory = $true)][string] $filename) {
	$extrargs = Get-Join " " @($filename, $Cfg.ExtraArgs)
	[MinerInfo]@{
		Pool = $Pool.PoolName()
		PoolKey = $Pool.PoolKey()
		Name = $Name
		Algorithm = $Algo
		Type = [eMinerType]::CPU
		API = "xmr-stak-cpu"
		URI = "https://github.com/fireice-uk/xmr-stak/releases/download/2.4.5/xmr-stak-win64.zip"
		Path = "$Name\xmr-stak-cpu.exe"
		ExtraArgs = $extrargs
		Arguments = $extrargs
		Port = 4047
		BenchmarkSeconds = $Cfg.BenchmarkSeconds
		RunBefore = $_.RunBefore
		RunAfter = $_.RunAfter
		Fee = 2
	}
}

function Save-XMRStak([Parameter(Mandatory = $true)][string] $Path, [int] $Count, [string] $Mask) {
	$nl = [Environment]::NewLine
	$nh = if ($Pool.Name -contains "nicehash") { "true" } else { "false" }
	$baseconfig = "`"use_slow_memory`": `"warn`"," + $nl +
		"`"nicehash_nonce`": $nh," + $nl +
		"`"pool_address`": `"$($Pool.Host):$($Pool.PortUnsecure)`"," + $nl +
		"`"wallet_address`": `"$($Pool.User)`"," + $nl +
		"`"pool_password`": `"$($Pool.Password)`"," + $nl +
		"`"call_timeout`": 10," + $nl +
		"`"retry_time`": 10," + $nl +
		"`"verbose_level`": 3," + $nl +
		"`"h_print_time`": 60," + $nl +
		"`"httpd_port`": 4047," + $nl +
		"`"prefer_ipv4`": true," + $nl +
		"`"aes_override`": true," + $nl +
		"`"use_tls`": false," + $nl +
		"`"tls_secure_algo`": true," + $nl +
		"`"tls_fingerprint`": `"`"," + $nl +
		"`"giveup_limit`": 0," + $nl +
		"`"daemon_mode`": false," + $nl +
		"`"output_file`": `"`""
	$threadconfig = "{{ `"low_power_mode`": false, `"no_prefetch`": true, `"affine_to_cpu`": {0} }},$nl"
	if (![string]::IsNullOrWhiteSpace($Mask)) {
		$Count = 0
		$i = 0
		$threads = [string]::Empty
		$Mask.ToCharArray() | ForEach-Object {
			if ($_ -eq "1") {
				$Count++
				$threads += $threadconfig -f $i
			}
			$i++
		}
		$result = "`"cpu_thread_num`": $Count," + $nl +
		"`"cpu_threads_conf`": [" + $nl + $threads + "],$nl" + $baseconfig
		$result | Out-File "$Path\affinity_$Mask.txt" -Force -Encoding ascii
		Get-XMRStak "affinity_$Mask.txt"
	}
	elseif ($Count -ge [Config]::Processors) {
		$result = "`"cpu_thread_num`": $Count," + $nl +
			"`"cpu_threads_conf`": [" + $nl
		for ($i = [Config]::Processors; $i -le $Count; $i++) {
			$result += $threadconfig -f "false"
		}
		$result += "],$nl" + $baseconfig
		$result | Out-File "$Path\$($Count)_threads.txt" -Force -Encoding ascii
		Get-XMRStak "$($Count)_threads.txt"
	}
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $true
	BenchmarkSeconds = 30
	ExtraArgs = $null
	ConfigFile = $null
	ThreadCount = $null
	ThreadMask = $null
})

if (!$Cfg.Enabled) { return }

$Algo = Get-Algo("cryptonight")
if ($Algo) {
	# find pool by algorithm
	$Pool = Get-Pool($Algo)
	if ($Pool) {

		$Path = Split-Path -Path ([IO.Path]::Combine($BinLocation, (Get-XMRStak [string]::Empty).Path))
		New-Item $Path -ItemType Directory -Force | Out-Null

		if ($Cfg.ConfigFile) {
			# by userconfig
			Get-XMRStak($Cfg.ConfigFile)
		}
		elseif ($Cfg.ThreadCount -or $Cfg.ThreadMask) {
			# by user settings
			Save-XMRStak $Path $Cfg.ThreadCount $Cfg.ThreadMask
		}
		else {
			# brute force
			# no affinity 
			for ([int] $i = [Config]::Processors; $i -le [Config]::Threads; $i++) {
				Save-XMRStak -Path $Path -Count $i
			}
			# with affinity
			Get-CPUMask | ForEach-Object {
				Save-XMRStak -Path $Path -Mask $_
			}
		}
	}
}
#>
