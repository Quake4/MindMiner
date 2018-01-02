<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Include.ps1

if (![Config]::Is64Bit) { exit }

function Get-XMRStak([Parameter(Mandatory = $true)][string] $filename) {
	[MinerInfo]@{
		Pool = $Pool.PoolName()
		PoolKey = $Pool.PoolKey()
		Name = $Name
		Algorithm = $Algo
		Type = [eMinerType]::CPU
		API = "xmr-stak-cpu"
		URI = "https://github.com/Quake4/MindMinerPrerequisites/raw/master/CPU/xmr-stak/xmr-stak-cpu-150.zip"
		Path = "$Name\xmr-stak-cpu.exe"
		ExtraArgs = $filename
		Arguments = $filename
		Port = 4047
		BenchmarkSeconds = $Cfg.BenchmarkSeconds
	}
}

function Save-XMRStak([Parameter(Mandatory = $true)][string] $Path, [int] $Count, [string] $Mask) {
	$nl = [Environment]::NewLine
	$nh = if ([string]::Equals($Pool.Name, "nicehash", [StringComparison]::InvariantCultureIgnoreCase)) { "true" } else { "false" }
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
	BenchmarkSeconds = 25
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
			Save-XMRStak($Cfg.ThreadCount, $Cfg.ThreadMask)
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