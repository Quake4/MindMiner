<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

class PoolInfo {
	[string] $Name
	[bool] $Enabled
	[string] $AverageProfit

	[datetime] $AnswerTime
	[bool] $HasAnswer

	[Collections.Generic.IList[PoolAlgorithmInfo]] $Algorithms

	PoolInfo() {
		$this.Algorithms = [Collections.Generic.List[PoolAlgorithmInfo]]::new()
	}
}

class PoolAlgorithmInfo {
	[string] $Name
	[string] $Algorithm
	[string] $Info
	[decimal] $Profit
	[string] $Protocol
	[string] $Host
	[int] $Port
	[int] $PortUnsecure
	[string] $User
	[string] $Password
	[bool] $ByLogin

	[string] PoolName() {
		if ($this.Info) {
			return "$($this.Name)-$($this.Info)"
		}
		else {
			return $this.Name
		}
	}

	[string] ToString() {
		return $this | Select-Object Name, Algorithm, Info, Profit, Protocol, Host, Port, PortUnsecure, User, Password
	}
}