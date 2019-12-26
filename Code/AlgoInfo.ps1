<#
MindMiner  Copyright (C) 2017-2019  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

class AlgoInfo {
	[bool] $Enabled
	[string] $Algorithm

	[string] ToString() {
		return $this | Select-Object Enabled, Algorithm
	}
}

class AlgoInfoEx : AlgoInfo {
	[string] $ExtraArgs
	[int] $BenchmarkSeconds
	
	[string] ToString() {
		return $this | Select-Object Enabled, Algorithm, ExtraArgs, BenchmarkSeconds
	}
}

class SpeedProfitInfo {
	[decimal] $Speed
	[decimal] $Profit
	[decimal] $MrrProfit

	[void] SetValue([decimal] $speed, [decimal] $profit, [bool] $mrr) {
		if ($mrr) {
			if ($this.MrrProfit -lt $profit) {
				$this.Speed = $speed
				$this.MrrProfit = $profit
			}
		}
		else {
			if ($this.Profit -lt $profit) {
				$this.Speed = $speed
				$this.Profit = $profit
			}
		}
	}
}