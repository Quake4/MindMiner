<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4/Quake3
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

# read/write/validate/store confirguration
class Config : BaseConfig {
	# replace [BaseConfig]::Filename
	static [string] $Filename = "config.txt"

	[string] $Region = [eRegion]::Europe
	[bool] $SSL = $true
	$Wallet = @{ BTC = "" }
	[string] $WorkerName = "MindMiner"
	[string] $Login
	[string] $Password = "x"
	[int] $CheckTimeout = 5
	[int] $LoopTimeout = 60
	[int] $NoHashTimeout = 7
	[int] $AverageCurrentHashSpeed = 180
	[string] $AverageHashSpeed = "1 day"
	[string[]] $AllowedTypes = @("CPU", "nVidia", "AMD", "Intel")

	static [bool] $Is64Bit = [Environment]::Is64BitOperatingSystem
	static [int] $Processors = 0
	static [int] $Cores = 0
	static [int] $Threads = 0
	static [string] $Version = "v0.1"
	static [string] $BinLocation = "Bin"
	static [eMinerType[]] $ActiveTypes = @([eMinerType]::CPU)
	static [string[]] $CPUFeatures
	static [timespan] $RateTimeout

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
								if (!$result.Contains($_) -and  "$($item.Value)".IndexOf($_, [StringComparison]::InvariantCultureIgnoreCase) -ge 0) {
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
		if ([string]::IsNullOrWhiteSpace($this.Wallet) -or [string]::IsNullOrWhiteSpace($this.Wallet.BTC)) {
			$result.Add("Wallet.BTC")
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
		if ($this.CheckTimeout -lt 3) {
			$this.CheckTimeout = 3
		}
		if ($this.LoopTimeout -lt 30) {
			$this.LoopTimeout = 30
		}
		if ($this.NoHashTimeout -lt 5) {
			$this.NoHashTimeout = 5
		}
		return [string]::Join(", ", $result.ToArray())
	}

	[string] ToString() {
		$pattern2 = "{0,15}: {1}$([Environment]::NewLine)"
		$pattern3 = "{0,15}: {1}{2}$([Environment]::NewLine)"
		$result = $pattern2 -f "Worker Name", $this.WorkerName +
			$pattern2 -f "Login:Password", ("{0}:{1}" -f $this.Login, $this.Password)
		$this.Wallet | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {		
			$result += $pattern2 -f "Wallet $_", $this.Wallet."$_"
		}
		$result += $pattern3 -f "Loop Timeout", $this.LoopTimeout, " sec" +
			$pattern3 -f "Check Timeout", $this.CheckTimeout, " sec" +
			$pattern3 -f "No Hash Timeout", $this.NoHashTimeout, " min" +
			$pattern2 -f "AVE Hash Speed", $this.AverageHashSpeed +
			$pattern3 -f "AVE Current HS", $this.AverageCurrentHashSpeed, " sec" +
			$pattern2 -f "OS 64Bit", [Config]::Is64Bit +
			$pattern2 -f "CPU & Features", ("{0}/{1}/{2} Processors/Cores/Threads & {3}" -f [Config]::Processors, [Config]::Cores, [Config]::Threads,
				[string]::Join(", ", [Config]::CPUFeatures)) +
			$pattern3 -f "Active Miners", [string]::Join(", ", [Config]::ActiveTypes), " <= Allowed: $([string]::Join(", ", $this.AllowedTypes))" +
			$pattern2 -f "Region", $this.Region +
			$pattern2 -f "Version", [Config]::Version
		return $result
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