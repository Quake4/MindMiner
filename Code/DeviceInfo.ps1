<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

class DeviceInfo {
	[string] $Name
	[decimal] $Power
}

class CPUInfo : DeviceInfo {
	[int] $Cores
	[int] $Threads
	[int] $Clock
	[string] $Features
	# [decimal] $Load
}

class GPUInfo : DeviceInfo {
	[decimal] $Load
	[decimal] $LoadMem
	[decimal] $Temperature
	[decimal] $Fan
	[decimal] $PowerLimit
	[decimal] $Clock
	[decimal] $ClockMem

	[void] CalcPower() {
		if ($this.Power -eq 0) {
			[int] $pwr = 0
			switch ($this.Name) {
				"RX Vega" { $pwr = 295 }
				"Vega 64" { $pwr = 295 }
				"Vega 56" { $pwr = 210 }
				"RX 590" { $pwr = 225 }
				"RX 580" { $pwr = 185 }
				"RX 480" { $pwr = 185 }
				"RX 570" { $pwr = 150 }
				"RX 470" { $pwr = 120 }
				"RX 560" { $pwr = 80 }
				"RX 460" { $pwr = 70 }
				"RX 550" { $pwr = 50 }
				"GTX 1050 Ti" { $pwr = 75 }
				"GTX 1050" { $pwr = 75 }
				Default {}
			}
			if ($pwr -gt 0) {
				$this.Power = [decimal]::Round($this.PowerLimit * $pwr * $this.Load / 10000, 1);
				if ($this.Power -eq 0) {
					$this.Power = [decimal]::Round($pwr / 10, 1);
				}
			}
		}
	}
}