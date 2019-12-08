<#
MindMiner  Copyright (C) 2017-2019  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

class BalanceInfo {
	[decimal] $Value
	[decimal] $Additional

	BalanceInfo([decimal] $value, [decimal] $additional) {
		$this.Value = $value
		$this.Additional = $additional
	}
}

class PoolInfo {
	[string] $Name
	[bool] $Enabled
	[string] $AverageProfit

	[datetime] $AnswerTime
	[bool] $HasAnswer

	[Collections.Generic.Dictionary[string, BalanceInfo]] $Balance

	[Collections.Generic.IList[PoolAlgorithmInfo]] $Algorithms

	PoolInfo() {
		$this.Algorithms = [Collections.Generic.List[PoolAlgorithmInfo]]::new()
		$this.Balance = [Collections.Generic.Dictionary[string, BalanceInfo]]::new()
	}
}

class PoolAlgorithmInfo {
	[string] $Name
	[Nullable[eMinerType]] $MinerType
	[string] $Info
	[bool] $InfoAsKey
	[string] $Algorithm
	[decimal] $Profit
	[string] $Protocol
	[string[]] $Hosts
	[int] $Port
	[int] $PortUnsecure
	[string] $User
	[string] $Password
	[Priority] $Priority

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
		return $this | Select-Object Name, Info, Algorithm, Profit, Protocol, Host, Port, PortUnsecure, User, Password, Priority
	}
}