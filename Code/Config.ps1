<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\BaseConfig.ps1
. .\Code\MinerInfo.ps1
. .\Code\Get-ManagementObject.ps1

enum eRegion {
	Europe
	Usa
	China
	Japan
	Other
}

enum eVerbose {
	Full
	Normal
	Minimal
}

# read/write/validate/store confirguration
class Config : BaseConfig {
	# replace [BaseConfig]::Filename
	static [string] $Filename = "config.txt"

	[string] $Region = [eRegion]::Europe
	[bool] $SSL = $true
	$Wallet = @{ BTC = "" }
	[string] $WorkerName = $env:COMPUTERNAME.Replace("DESKTOP-", [string]::Empty)
	[string] $Login
	[string] $Password = "x"
	[int] $CheckTimeout = 5
	[int] $LoopTimeout = 60
	[int] $NoHashTimeout = 10
	[int] $AverageCurrentHashSpeed = 180
	[string] $AverageHashSpeed = "1 day"
	[string[]] $AllowedTypes = @("CPU", "nVidia", "AMD", "Intel")
	[string] $Verbose = [eVerbose]::Normal
	[Nullable[bool]] $ShowBalance = $true
	$Currencies
	[int] $CoolDown
	[bool] $ApiServer
	$SwitchingResistance = @{ "Enabled" = $true; "Percent" = 4; "Timeout" = 15 }
	$BenchmarkSeconds
	[int] $MinimumMiners = 5

	static [bool] $Is64Bit = [Environment]::Is64BitOperatingSystem
	static [int] $Processors = 0
	static [int] $Cores = 0
	static [int] $Threads = 0
	static [string] $Version = "v2.53"
	static [string] $BinLocation = "Bin"
	static [string] $MinersLocation = "Miners"
	static [string] $PoolsLocation = "Pools"
	static [string] $StatsLocation = "Stats"
	static [string] $RunLocation = "Run"
	static [eMinerType[]] $ActiveTypes
	static [string[]] $CPUFeatures
	static [int] $AMDPlatformId
	static [timespan] $RateTimeout
	static [int] $FTimeout = 120
	static [decimal] $CurrentOf24h = 0.5
	static [decimal] $MaxTrustGrow = 1.5
	static [int] $SmallTimeout = 100
	static [int] $ApiPort = 5555
	static [string] $Placeholder = "%%"
	static [string] $WorkerNamePlaceholder = "%%WorkerName%%"
	static [string] $WalletPlaceholder = "%%Wallet.{0}%%"
	static [string] $LoginPlaceholder = "%%Login%%"
	static [bool] $UseApiProxy = $false

	static Config() {
		Get-ManagementObject "select * from Win32_Processor" {
			Param([Management.ManagementObjectCollection] $items)
			foreach ($each in $items) {
				[Config]::Processors += 1
				foreach ($item in $each.Properties) {
					if ($item.Name -eq "NumberOfCores") {
						[Config]::Cores += [int]::Parse($item.Value)
					}
					elseif ($item.Name -eq "NumberOfLogicalProcessors") {
						[Config]::Threads += [int]::Parse($item.Value)
					}
				}
			}
		}
		$result = [Collections.Generic.List[string]]::new()
		$result.Add([eMinerType]::CPU)
		Get-ManagementObject "select * from Win32_VideoController" {
			Param([Management.ManagementObjectCollection] $items)
			foreach ($each in $items) {
				# Write-Host $each
				foreach ($item in $each.Properties) {
					# Write-Host $item.Name, $item.Value
					if ($item.Name -eq "AdapterCompatibility" -or $item.Name -eq "Caption" -or $item.Name -eq "Description" -or
					$item.Name -eq "Name" -or $item.Name -eq "VideoProcessor") {
						if (![string]::IsNullOrWhiteSpace($item.Value)) {
							[Enum]::GetNames([eMinerType]) | ForEach-Object {
								if (!$result.Contains($_) -and "$($item.Value)".IndexOf($_, [StringComparison]::InvariantCultureIgnoreCase) -ge 0) {
									$result.Add($_)
								}
							}
						}
					}
				}
			}
		}
		[Config]::ActiveTypes = $result.ToArray()
	}

	# save config file
	[void] Save() {
		$this.Save([Config]::Filename)
	}

	# validate readed config file
	[string] Validate() {
		$result = [Collections.ArrayList]::new()
		if ([string]::IsNullOrWhiteSpace($this.Wallet) -or ([string]::IsNullOrWhiteSpace($this.Wallet.BTC) -and [string]::IsNullOrWhiteSpace($this.Wallet.LTC))) {
			$result.Add("Wallet.BTC")
		}
		if ([string]::IsNullOrWhiteSpace($this.WorkerName)) {
			$this.WorkerName = $env:COMPUTERNAME;
		}
		if (![string]::IsNullOrWhiteSpace($this.WorkerName)) {
			$this.WorkerName = $this.WorkerName.Replace("DESKTOP-", [string]::Empty)
		}
		if ([string]::IsNullOrWhiteSpace($this.WorkerName)) {
			$result.Add("WorkerName")
		}
		if (!(($this.Region -as [eRegion]) -is [eRegion])) {
			$result.Add("Region")
		}
		else {
			$this.Region = $this.Region -as [eRegion]
		}
		if (!(($this.Verbose -as [eVerbose]) -is [eVerbose])) {
			$result.Add("Verbose")
		}
		else {
			$this.Verbose = $this.Verbose -as [eVerbose]
		}
		if ($this.CheckTimeout -lt 3) {
			$this.CheckTimeout = 3
		}
		if ($this.LoopTimeout -lt 60) {
			$this.LoopTimeout = 60
		}
		if ($this.NoHashTimeout -lt 5) {
			$this.NoHashTimeout = 5
		}
		# if readed from file need to convert from PSCustomObject
		if ($this.Currencies -is [PSCustomObject]) {
			$hash = [Collections.Generic.List[object]]::new()
			$this.Currencies = "$($this.Currencies)".Split(@("@", "}", "{", " ", ";"), [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
				$each = "$_".Split(@("="), [StringSplitOptions]::RemoveEmptyEntries)
				$hash.Add(@($each[0]; $each[1]))
			}
			# $this.Currencies | Get-Member -MemberType NoteProperty | ForEach-Object { $hash.Add(@($_.Name; $this.Currencies."$($_.Name)")) }
			$this.Currencies = $hash
		}
		if ($this.ShowBalance -eq $null) { # possible, not use code
			$this.ShowBalance = $true
		}
		if ($this.SwitchingResistance -and $this.SwitchingResistance.Enabled -and
			($this.SwitchingResistance.Percent -le 0 -or $this.SwitchingResistance.Timeout -lt $this.LoopTimeout / 60)) {
			$this.SwitchingResistance.Enabled = $false
		}
		return [string]::Join(", ", $result.ToArray())
	}

	[string] ToString() {
		$pattern2 = "{0,26}: {1}$([Environment]::NewLine)"
		$pattern3 = "{0,26}: {1}{2}$([Environment]::NewLine)"
		$result = $pattern2 -f "Worker Name", $this.WorkerName +
			$pattern2 -f "Login:Password", ("{0}:{1}" -f $this.Login, $this.Password)
		$this.Wallet | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
			$result += $pattern2 -f "Wallet $_", $this.Wallet."$_"
		}
		$features = if ([Config]::CPUFeatures) { [string]::Join(", ", [Config]::CPUFeatures) } else { [string]::Empty }
		$types = if ([Config]::ActiveTypes.Length -gt 0) { [string]::Join(", ", [Config]::ActiveTypes) } else { "Unknown" }
		$api = if ($global:API.Running -ne $null) { if ($global:API.Running) { "Running at $($global:API.RunningMode) access mode" } else { "Stopped" } } else { if ($this.ApiServer) { "Unknown" } else { "Disabled" } }
		$result += $pattern2 -f "Timeout Loop/Check/NoHash", ("{0} sec/{1} sec/{2} min" -f $this.LoopTimeout, $this.CheckTimeout, $this.NoHashTimeout) +
			$pattern2 -f "Average Hash Speed/Current", ("{0}/{1} sec" -f $this.AverageHashSpeed, $this.AverageCurrentHashSpeed) +
			$pattern2 -f "Switching Resistance", ("{0} as {1}% or {2} min" -f $this.SwitchingResistance.Enabled, $this.SwitchingResistance.Percent, $this.SwitchingResistance.Timeout) +
			$pattern2 -f "CPU & Features", ("{0}/{1}/{2} Procs/Cores/Threads & {3}" -f [Config]::Processors, [Config]::Cores, [Config]::Threads, $features) +
			$pattern3 -f "Active Miners", $types, " <= Allowed: $([string]::Join(", ", $this.AllowedTypes))" +
			$pattern2 -f "API Server", $api +
			$pattern2 -f "Region", $this.Region
		return $result
	}

	[PSCustomObject] Web() {
		$result = @{}
		$result."Login:Password" = ("{0}:{1}" -f $this.Login, $this.Password)
		$this.Wallet | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
			$result."Wallet $_" = $this.Wallet.$_
		}
		$result."Region" = $this.Region
		return [PSCustomObject]$result
	}

	static [bool] Exists() {
		return [Config]::Exists([Config]::Filename)
	}

	static [Config] Read() {
		$hash = [Config]::Read([Config]::Filename)
		if ($hash) {
			return [Config] $hash
		}
		return $null
	}
}