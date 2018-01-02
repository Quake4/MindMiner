<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

class BalanceInfo {
	[decimal] $Value
	[decimal] $Additional
}

class PoolInfo {
	[string] $Name
	[bool] $Enabled
	[string] $AverageProfit

	[datetime] $AnswerTime
	[bool] $HasAnswer

	[BalanceInfo] $Balance

	[Collections.Generic.IList[PoolAlgorithmInfo]] $Algorithms

	PoolInfo() {
		$this.Algorithms = [Collections.Generic.List[PoolAlgorithmInfo]]::new()
		$this.Balance = [BalanceInfo]::new()
	}
}

class PoolAlgorithmInfo {
	[string] $Name
	[string] $Info
	[bool] $InfoAsKey
	[string] $Algorithm
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

	[string] PoolKey() {
		if ($this.InfoAsKey -and $this.Info) {
			return "$($this.Name)-$($this.Info)"
		}
		else {
			return $this.Name
		}
	}

	[string] ToString() {
		return $this | Select-Object Name, Info, Algorithm, Profit, Protocol, Host, Port, PortUnsecure, User, Password
	}
}