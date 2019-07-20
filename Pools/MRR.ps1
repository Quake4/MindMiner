<#
MindMiner  Copyright (C) 2018-2019  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

$PoolInfo = [PoolInfo]::new()
$PoolInfo.Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$configfile = $PoolInfo.Name + [BaseConfig]::Filename
$configpath = [IO.Path]::Combine($PSScriptRoot, $configfile)

$Cfg = ReadOrCreatePoolConfig "Do you want to pass a rig to rent on $($PoolInfo.Name)" $configpath @{
	Enabled = $false
	Key = $null
	Secret = $null
	Region = $null
	EnabledAlgorithms = $null
	DisabledAlgorithms = $null
}

if ($global:HasConfirm -eq $true -and $Cfg -and [string]::IsNullOrWhiteSpace($Cfg.Key) -and [string]::IsNullOrWhiteSpace($Cfg.Secret)) {
	Write-Host "Create Api Key on `"https://www.miningrigrentals.com/account/apikey`" with grant to `"Manage Rigs`"." -ForegroundColor Yellow
	$Cfg.Key = Read-Host "Enter `"Key`""
	$Cfg.Secret = Read-Host "Enter `"Secret`""
	[BaseConfig]::Save($configpath, $Cfg)
}

if ($global:AskPools -eq $true -or !$Cfg) { return $null }

$PoolInfo.Enabled = $Cfg.Enabled

if (!$Cfg.Enabled) { return $PoolInfo }

if ([string]::IsNullOrWhiteSpace($Cfg.Key) -or [string]::IsNullOrWhiteSpace($Cfg.Secret)) {
	Write-Host "Fill in the `"Key`" and `"Secret`" parameters in the configuration file `"$configfile`" or disable the $($PoolInfo.Name)." -ForegroundColor Yellow
	return $null
}

try {
	$servers = Get-UrlAsJson "https://www.miningrigrentals.com/api/v2/info/servers"
	if (!$servers -or !$servers.success) {
		throw [Exception]::new()
	}
}
catch { return $PoolInfo }

if ([string]::IsNullOrWhiteSpace($Cfg.Region)) {
	$Cfg.Region = "us-central"
	switch ($Config.Region) {
		"$([eRegion]::Europe)" { $Cfg.Region = "eu" }
		"$([eRegion]::China)" { $Cfg.Region = "ap" }
		"$([eRegion]::Japan)" { $Cfg.Region = "ap" }
	}
	if ($Cfg.Region -eq "eu") {
		[string] $locale = "$($Cfg.Region)-$((Get-Host).CurrentCulture.TwoLetterISOLanguageName)"
		if ($servers.data | Where-Object { $_.region -match $locale }) {
			$Cfg.Region = $locale
		}
	}
}
$server = $servers.data | Where-Object { $_.region -match $Cfg.Region } | Select-Object -First 1	

if (!$server -or $server.Length -gt 1) {
	$servers = $servers.data | Select-Object -ExpandProperty region
	Write-Host "Set `"Region`" parameter from list ($(Get-Join ", " $servers)) in the configuration file `"$configfile`" or disable the $($PoolInfo.Name)." -ForegroundColor Yellow
	return $null;
}

# info as standart pool
$PoolInfo.HasAnswer = $true
$PoolInfo.AnswerTime = [DateTime]::Now
$PoolInfo.Algorithms.Add([PoolAlgorithmInfo] @{
	Name = $PoolInfo.Name
	Algorithm = "MiningRigRentals"
	Profit = 1
	Info = "Fake"
	Protocol = "stratum+tcp"
	Host = $server.name
	Port = $server.port
	PortUnsecure = $server.port
	User = "MindMiner"
	Password = "x"
})
# check rented
try {
	$mrr = [MRR]::new($Cfg.Key, $Cfg.Secret);
	$mrr.Debug = $true;
	$whoami = $mrr.Get("/whoami")
	if (!$whoami.authed) {
		Write-Host "MRR: Not authorized! Check Key and Secret." -ForegroundColor Yellow
		return $null;
	}
	# check rigs
	$worker = "$($whoami.username)\W+$($Config.WorkerName)"
	$result = $mrr.Get("/rig/mine") | Where-Object { $_.name -match "^$worker" }
	if ($result) {
		$rented_types = @()
		$rented_ids = @()
		$exclude_ids = @()
		$result | ForEach-Object {
			$name = $_.name.TrimStart($whoami.username).Trim().Trim("-").TrimStart($Config.WorkerName).Trim()
			if (![string]::IsNullOrWhiteSpace($name)) {
				$type = ($name -split "\W")[0] -as [eMinerType]
				if ($null -ne $type -and $AllAlgos.Miners.$type -contains $_.type) {
					$Pool_Algorithm = Get-Algo $_.type
					if ($Pool_Algorithm) {
						if ( -and $rented_types -notcontains "^$worker\W+$type") {
							if ([Config]::ActiveTypes -contains $type -and $_.status.rented) {
								$rented_types += "^$worker\W+$type"
								$rented_ids += $_.id
								$_.price.type = $_.price.type.ToLower().TrimEnd("h")
								$Profit = [decimal]$_.price.BTC.price / [MultipleUnit]::ToValueInvariant("1", $_.price.type)
								$PoolInfo.Algorithms.Add([PoolAlgorithmInfo] @{
									Name = $PoolInfo.Name
									MinerType = $type -as [eMinerType]
									Algorithm = $Pool_Algorithm
									Profit = $Profit
									Info = $_.status.hours
									Protocol = "stratum+tcp"
									Host = $server.name
									Port = $server.port
									PortUnsecure = $server.port
									User = "$($whoami.username).$($_.id)"
									Password = "x"
								})
							}
							elseif ([Config]::ActiveTypes -notcontains $type) {
								$rented_types += "^$worker\W+$type"
							}
						}
					}
				}
				else {
					$disable_ids += $_.id
				}
			}
			else {
				$exclude_ids += $_.id
			}
		}

		$disable_ids = @()
		$rented_types | ForEach-Object {
			$rented_type = $_
			$result | Where-Object { $_.available_status -match "available" -and $_.name -match $rented_type -and $rented_ids -notcontains $_.id -and $exclude_ids -notcontains $_.id } | ForEach-Object {
				$disable_ids += $_.id
			}
		}
		if ($disable_ids.Length -gt 0) {
			$mrr.Put("/rig/$($disable_ids -join ';')", @{ "status" = "disabled" })
		}

		$enabled_ids = @()
		$rented_types | ForEach-Object {
			$rented_type = $_
			$result | Where-Object { $_.available_status -notmatch "available" -and $_.name -notmatch $rented_type -and $disable_ids -notcontains $_.id -and $rented_ids -notcontains $_.id -and $exclude_ids -notcontains $_.id } | ForEach-Object {
				$enabled_ids += $_.id
			}
		}
		if ($enabled_ids.Length -gt 0) {
			$mrr.Put("/rig/$($enabled_ids -join ';')", @{ "status" = "enabled" })
		}
	}
}
catch {
	Write-Host $_
}
finally {
	if ($mrr) {	$mrr.Dispose() }
}
return $PoolInfo
<#
	try {
		$algos = Get-UrlAsJson "https://www.miningrigrentals.com/api/v2/info/algos"
		if (!$algos -or !$algos.success) {
			throw [Exception]::new()
		}
	}
	catch { return $null }




	$algos.data | ForEach-Object {
		$Algo = $_
		$Pool_Algorithm = Get-Algo ($Algo.name) $false
		if ($Pool_Algorithm -and (!$Cfg.EnabledAlgorithms -or $Cfg.EnabledAlgorithms -contains $Pool_Algorithm) -and $Cfg.DisabledAlgorithms -notcontains $Pool_Algorithm) {
			$Algo.suggested_price.unit = $Algo.suggested_price.unit.ToLower().TrimEnd("h*day")
			$Profit = [decimal]$Algo.suggested_price.amount / [MultipleUnit]::ToValueInvariant("1", $Algo.suggested_price.unit)
			$PoolInfo.Algorithms.Add([PoolAlgorithmInfo] @{
				Name = $PoolInfo.Name
				Algorithm = $Pool_Algorithm
				Profit = $Profit
				Info = "$($Algo.stats.rented.rigs)/$($Algo.stats.available.rigs)"
				Protocol = "stratum+tcp"
				Host = $server.name
				Port = $server.port
				PortUnsecure = $server.port
				User = "MindMiner"
				Password = "x"
			})
		}
	}

	try {
		$mrr = [MRR]::new($Cfg.Key, $Cfg.Secret);
		$mrr.Debug = $true;
		$result = $mrr.Get("/whoami")
		if (!$result.authed) {
			Write-Host "MRR: Not authorized! Check Key and Secret." -ForegroundColor Yellow
			return $null;
		}
		if ($result.permissions.rigs -ne "yes") {
			Write-Host "MRR: Need grant `"Manage Rigs`"." -ForegroundColor Yellow
			return $null;
		}

		# check rigs

		# $AllAlgos.Miners -contains $Pool_Algorithm

		$result = $mrr.Get("/rig/mine") | Where-Object { $_.name -match $Config.WorkerName }
		if ($result) {

		}
		else {
			# create rigs on all algos
		}

		# if rented
		$rented = $null
		$rented
	}
	catch {
		Write-Host $_
	}
	finally {
		if ($mrr) {	$mrr.Dispose() }
	}
#>