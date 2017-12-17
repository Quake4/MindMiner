<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

function Get-CPUMask {
	[Collections.Generic.List[string]] $result = [Collections.Generic.List[string]]::new()
	if ([Config]::Cores -eq [Config]::Threads) {
		# simplify if cores equals threads: 0001 0011 0111 1111
		for ($i = 1; $i -le ([Config]::Cores / [Config]::Processors); $i++) {
			$mask = [string]::Empty
			for ($j = 1; $j -le [Config]::Processors; $j ++) {
				$mask += [string]::new('1', $i).PadLeft([Config]::Cores / [Config]::Processors, "0")
			}
			$result.Add($mask)
		}
	}
	<# else {
		# need simplify: 24 thread equal 16 777 216 variations
		for ($i = 1; $i -lt [Math]::Pow(2, [Config]::Threads); $i++) {
			$val = [Convert]::ToString($i, 2).PadLeft([Config]::Threads, "0")
			$reverce = $val.ToCharArray()
			[array]::Reverse($reverce)
			if (!$result.Contains([string]::new($reverce))) {
				$result.Add($val)
			}
		}
	}#>
	$result
}