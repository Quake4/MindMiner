<#
MindMiner  Copyright (C) 2017-2018  Oleg Samsonov aka Quake4
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

enum eSwitching {
	Normal
	Fast
}

enum eWindowStyle {
	Hidden
	Maximized
	Minimized
	Normal
}

# read/write/validate/store confirguration
class Config : BaseConfig {
	# replace [BaseConfig]::Filename
	static [string] $Filename = "config.txt"

	[string] $Region = [eRegion]::Europe
	[bool] $SSL = $true
	$Wallet = @{ BTC = "" }
	[string] $WorkerName = $env:COMPUTERNAME.Replace("DESKTOP-", [string]::Empty).Replace("WIN-", [string]::Empty)
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
	[Nullable[bool]] $ShowExchangeRate = $false
	$Currencies
	[int] $CoolDown
	[bool] $ApiServer
	$SwitchingResistance = @{ "Enabled" = $true; "Percent" = 5; "Timeout" = 12 }
	[string] $Switching = [eSwitching]::Normal
	$BenchmarkSeconds
	[int] $MinimumMiners = 25
	[string] $MinerWindowStyle = [eWindowStyle]::Minimized
	[string] $ApiKey
	[bool] $ConfirmMiner = $false
	$LowerFloor
	[bool] $DevicesStatus = $true
	$ElectricityPrice
	[bool] $ElectricityConsumption = $false

	static [bool] $Is64Bit = [Environment]::Is64BitOperatingSystem
	static [string] $Version = "v3.32"
	static [string] $BinLocation = "Bin"
	static [string] $MinersLocation = "Miners"
	static [string] $PoolsLocation = "Pools"
	static [string] $StatsLocation = "Stats"
	static [string] $RunLocation = "Run"
	static [eMinerType[]] $ActiveTypes
	static [string[]] $CPUFeatures
	static [int] $AMDPlatformId
	static [version] $CudaVersion
	static [timespan] $RateTimeout
	static [int] $FTimeout = 160
	static [decimal] $MaxTrustGrow = 2
	static [int] $SmallTimeout = 100
	static [int] $ApiPort = 5555
	static [string] $Placeholder = "%%"
	static [string] $WorkerNamePlaceholder = "%%WorkerName%%"
	static [string] $WalletPlaceholder = "%%Wallet.{0}%%"
	static [string] $LoginPlaceholder = "%%Login%%"
	static [bool] $UseApiProxy = $false
	static [string] $SMIPath = [IO.Path]::Combine([environment]::GetFolderPath([environment+SpecialFolder]::ProgramFiles), "NVIDIA Corporation\NVSMI\nvidia-smi.exe")

	static Config() {
		$result = [Collections.Generic.List[string]]::new()
		$result.Add([eMinerType]::CPU)
		Get-ManagementObject "select * from Win32_VideoController" {
			Param([Management.ManagementObjectCollection] $items)
			foreach ($each in $items) {
				# Write-Host $each
				foreach ($item in $each.Properties) {
					# Write-Host $item.Name, $item.Value
					if ($item.Name -eq "AdapterCompatibility" -or $item.Name -eq "Caption" -or $item.Name -eq "Description" -or $item.Name -eq "Name" -or $item.Name -eq "VideoProcessor") {
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
		if (!($this.Wallet | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name)) {
			$result.Add("Wallet.BTC and/or Wallet.LTC and/or Wallet.NiceHash")
		}
		if ([string]::IsNullOrWhiteSpace($this.WorkerName)) {
			$this.WorkerName = $env:COMPUTERNAME;
		}
		if (![string]::IsNullOrWhiteSpace($this.WorkerName)) {
			$this.WorkerName = $this.WorkerName.Replace("DESKTOP-", [string]::Empty).Replace("WIN-", [string]::Empty)
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
		if (!(($this.Switching -as [eSwitching]) -is [eSwitching])) {
			$result.Add("Switching")
		}
		else {
			$this.Switching = $this.Switching -as [eSwitching]
		}
		if (!(($this.MinerWindowStyle -as [eWindowStyle]) -is [eWindowStyle])) {
			$this.MinerWindowStyle = [eWindowStyle]::Minimized
		}
		else {
			$this.MinerWindowStyle = $this.MinerWindowStyle -as [eWindowStyle]
		}
		if ($this.CheckTimeout -lt 3) {
			$this.CheckTimeout = 3
		}
		if ($this.LoopTimeout -lt 40) {
			$this.LoopTimeout = 40
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
		if ($null -eq $this.ShowBalance) { # possible, not use code
			$this.ShowBalance = $true
		}
		if ($null -eq $this.ShowExchangeRate) { # possible, not use code
			$this.ShowExchangeRate = $true
		}
		if ($this.SwitchingResistance -and $this.SwitchingResistance.Enabled -and
			($this.SwitchingResistance.Percent -le 0 -or $this.SwitchingResistance.Timeout -lt $this.LoopTimeout / 60)) {
			$this.SwitchingResistance.Enabled = $false
		}
		return [string]::Join(", ", $result.ToArray())
	}

	[string] ToString() {
		return $this.ToString($true);
	}

	[string] ToString([bool] $full) {
		$pattern2 = "{0,26}: {1}$([Environment]::NewLine)"
		$pattern3 = "{0,26}: {1}{2}$([Environment]::NewLine)"
		$result = $pattern2 -f "Worker Name", $this.WorkerName
		if (![string]::IsNullOrWhiteSpace($this.ApiKey)) {
			$result += $pattern2 -f "Monitoring API Key ID", $this.ApiKey
		}
		if (![string]::IsNullOrWhiteSpace($this.Login)) {
			$result += $pattern2 -f "Login:Password", ("{0}:{1}" -f $this.Login, $this.Password)
		}
		$this.Wallet | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
			$result += $pattern2 -f "Wallet $_", $this.Wallet."$_"
		}
		if ($this.LowerFloor -and $full) {
			$result +=  $pattern2 -f "Profitability Lower Floor", (($this.LowerFloor | ConvertTo-Json -Compress | Out-String).Replace([environment]::NewLine, [string]::Empty).Replace(",", ", ").Replace(":", ": "))
		}
		if ($this.ElectricityPrice -and $full) {
			$result +=  $pattern3 -f "Electricity Account/Price", "$($this.ElectricityConsumption)/", (($this.ElectricityPrice | ConvertTo-Json -Compress | Out-String).Replace([environment]::NewLine, [string]::Empty).Replace(",", ", ").Replace(":", ": "))
		}
		if ($full) {
			$types = if ([Config]::ActiveTypes.Length -gt 0) { [string]::Join(", ", [Config]::ActiveTypes) } else { "None" }
			$sr = if ($this.SwitchingResistance.Enabled) { "{0} as {1}% or {2} min" -f $this.SwitchingResistance.Enabled, $this.SwitchingResistance.Percent, $this.SwitchingResistance.Timeout } else { "$($this.SwitchingResistance.Enabled)" }
			$result += $pattern2 -f "Timeout Loop/Check/No Hash", ("{0} sec/{1} sec/{2} min" -f $this.LoopTimeout, $this.CheckTimeout, $this.NoHashTimeout) +
				$pattern2 -f "Hash Speed Average/Current", ("{0}/{1} sec" -f $this.AverageHashSpeed, $this.AverageCurrentHashSpeed) +
				$pattern2 -f "Switching Resistance", $sr +
				$pattern3 -f "Active Miners", $types, " <= Allowed: $([string]::Join(", ", $this.AllowedTypes))"
		}
		$api = if ($null -ne $global:API.Running) { if ($global:API.Running) { "Running at $($global:API.RunningMode) access mode" } else { "Stopped" } } else { if ($this.ApiServer) { "Unknown" } else { "Disabled" } }
		$result += $pattern2 -f "API Server", $api
		if ($full) {
			$result += $pattern2 -f "Region", $this.Region
		}
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
