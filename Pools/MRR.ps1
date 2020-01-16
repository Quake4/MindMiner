<#
MindMiner  Copyright (C) 2018-2020  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

$PoolInfo = [PoolInfo]::new()
$PoolInfo.Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$configfile = $PoolInfo.Name + [BaseConfig]::Filename
$configpath = [IO.Path]::Combine($PSScriptRoot, $configfile)

$Cfg = ReadOrCreatePoolConfig "Do you want to pass a rig to rent on $($PoolInfo.Name) (1% extra fee)" $configpath @{
	Enabled = $false
	Key = $null
	Secret = $null
	Region = $null
	DisabledAlgorithms = $null
	Wallets = $null
	Target = 50
	Increase = 5
	Decrease = 1
	MinHours = 4
	MaxHours = 12
}

if ($global:HasConfirm -and $Cfg -and $Cfg.Enabled -and [string]::IsNullOrWhiteSpace($Cfg.Key) -and [string]::IsNullOrWhiteSpace($Cfg.Secret)) {
	Write-Host "Create Api Key on `"https://www.miningrigrentals.com/account/apikey`" with grant to `"Manage Rigs`" as `"Yes`"." -ForegroundColor Yellow
	$Cfg.Key = Read-Host "Enter `"Key`""
	$Cfg.Secret = Read-Host "Enter `"Secret`""
	# ask wallets
	[Config]::MRRWallets | ForEach-Object {
		if (Get-Question "Do you want to accept payment in '$($_.ToUpper())'") {
			if (!$Cfg.Wallets) { $Cfg.Wallets = @() }
			$Cfg.Wallets += "$_"
		}
	}
	# save config
	[BaseConfig]::Save($configpath, $Cfg)
}

if ($global:AskPools -eq $true -or !$Cfg) { return $null }

$PoolInfo.Enabled = $Cfg.Enabled
if (!$Cfg.Enabled) { return $PoolInfo }
if (!$Cfg.DisabledAlgorithms) { $Cfg.DisabledAlgorithms = @() }

if ([string]::IsNullOrWhiteSpace($Cfg.Key) -or [string]::IsNullOrWhiteSpace($Cfg.Secret)) {
	Write-Host "Fill in the `"Key`" and `"Secret`" parameters in the configuration file `"$configfile`" or disable the $($PoolInfo.Name)." -ForegroundColor Yellow
	return $PoolInfo
}

$servers = Get-Rest "https://www.miningrigrentals.com/api/v2/info/servers"
if (!$servers -or !$servers.success) {
	return $PoolInfo
}

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
	return $PoolInfo;
}

# check algorithms
$AlgosRequest = Get-Rest "https://www.miningrigrentals.com/api/v2/info/algos"
if (!$AlgosRequest -or !$AlgosRequest.success) {
	return $PoolInfo
}

$Algos = [Collections.Generic.Dictionary[string, PoolAlgorithmInfo]]::new()
$AlgosRequest.data | ForEach-Object {
	$Algo = $_
	$Pool_Algorithm = Get-MRRAlgo $Algo.name
	if ($Pool_Algorithm -and $Cfg.DisabledAlgorithms -notcontains $Pool_Algorithm) {
		$Algo.stats.prices.last_10.amount = [decimal]$Algo.stats.prices.last_10.amount
		[decimal] $Price = 0
		if ($Algo.stats.prices.last_10.amount -gt 0) {
			$Price = $Algo.stats.prices.last_10.amount / [MultipleUnit]::ToValueInvariant("1", $Algo.stats.prices.last_10.unit.ToLower().TrimEnd("h*day"))
		}
		else {
			$Price = [decimal]$Algo.suggested_price.amount / [MultipleUnit]::ToValueInvariant("1", $Algo.suggested_price.unit.ToLower().TrimEnd("h*day"))
		}

		$percent = 0;

		$Algo.stats.rented.rigs = [int]$Algo.stats.rented.rigs
		$Algo.stats.available.rigs = [int]$Algo.stats.available.rigs
		if (($Algo.stats.rented.rigs + $Algo.stats.available.rigs) -gt 0) {
			$percent = $Algo.stats.rented.rigs / ($Algo.stats.rented.rigs + $Algo.stats.available.rigs) * 100
		}

		if (![string]::IsNullOrEmpty($Algo.stats.rented.hash.hash) -and ![string]::IsNullOrEmpty($Algo.stats.available.hash.hash)) {
			$rented = [MultipleUnit]::ToValueInvariant($Algo.stats.rented.hash.hash, $Algo.stats.rented.hash.unit -replace "h")
			$avail = [MultipleUnit]::ToValueInvariant($Algo.stats.available.hash.hash, $Algo.stats.available.hash.unit -replace "h")
			if (($rented + $avail) -gt 0) {
				$percent = [Math]::Max($percent, $rented / ($rented + $avail) * 100)
			}
		}

		$info = Get-Join "/" @($(if ($Algo.stats.rented.rigs -eq 0) { "0" } else { "$($Algo.stats.rented.rigs)($($Algo.stats.rented.hash.nice))" }),
			$(if ($Algo.stats.available.rigs -eq 0) { "0" } else { "$($Algo.stats.available.rigs)($($Algo.stats.available.hash.nice))" }))
		$Algos[$Pool_Algorithm] = [PoolAlgorithmInfo] @{
			Name = $PoolInfo.Name
			Algorithm = $Pool_Algorithm
			Profit = 0 # $Profit
			Price = $Price
			Info = $info
			Protocol = "stratum+tcp"
			Hosts = @($server.name)
			Port = $server.port
			PortUnsecure = $server.port
			User = $Algo.name
			Password = $percent
			Priority = [Priority]::None
		}
	}
}

# check rented
try {
	$mrr = [MRR]::new($Cfg.Key, $Cfg.Secret);
	# $mrr.Debug = $true;
	$whoami = $mrr.Get("/whoami")
	if (!$whoami.authed) {
		$whoami = $mrr.Get("/whoami")
		if (!$whoami.authed) {
			Write-Host "MRR: Not authorized! Check Key and Secret." -ForegroundColor Yellow
			return $PoolInfo;
		}
	}
	if ($whoami.permissions.rigs -ne "yes") {
		Write-Host "MRR: Need grant 'Manage Rigs' as 'Yes'." -ForegroundColor Yellow
		return $PoolInfo;
	}

	# check variables
	if (!$Cfg.Target -or $Cfg.Target -lt 5) {
		$Cfg.Target = 50
	}
	if ($Cfg.Target -gt 899) {
		$Cfg.Target = 899
	}
	if (!$Cfg.Increase -or $Cfg.Increase -lt 0) {
		$Cfg.Increase = 5
	}
	if ($Cfg.Increase -gt 25) {
		$Cfg.Increase = 25
	}
	if (!$Cfg.Decrease -or $Cfg.Decrease -lt 0) {
		$Cfg.Decrease = 1
	}
	if ($Cfg.Decrease -gt 25) {
		$Cfg.Decrease = 25
	}
	if (!$Cfg.MinHours -or $Cfg.MinHours -lt 3) {
		$Cfg.MinHours = 4
	}
	if ($Cfg.MinHours -gt 120) {
		$Cfg.MinHours = 120
	}
	if (!$Cfg.MaxHours) {
		$Cfg.MaxHours = 12
	}
	if ($Cfg.MaxHours -gt 120) {
		$Cfg.MaxHours = 120
	}
	if ($Cfg.MaxHours -lt $Cfg.MinHours) {
		$Cfg.MaxHours = $Cfg.MinHours
	}

	# balance
	if ($Config.ShowBalance -and $whoami.permissions.withdraw -ne "no") {
		$balance = $mrr.Get("/account/balance")
		$balance | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
			$confirmed = [decimal]$balance.$_.confirmed
			$unconfirmed = [decimal]$balance.$_.unconfirmed
			if ($confirmed -gt 0 -or $unconfirmed -gt 0) {
				$PoolInfo.Balance.Add($_, [BalanceInfo]::new($confirmed, $unconfirmed))
			}
		}
	}

	$PrevRented = $global:MRRRented
	$global:MRRRented = @()

	# check rigs
	$result = $mrr.Get("/rig/mine") | Where-Object { $_.name -match $Config.WorkerName }
	if ($result) {
		$rented_ids = @()
		$rented_types = @()
		$disable_ids = @()
		$enabled_ids = @()
		# smaller max
		if ([Config]::Max -eq 100) { [Config]::Max = 50 }
		# reset rented
		$result | ForEach-Object {
			$_.status.rented = $_.status.rented -and [decimal]$_.status.hours -gt 0
		}
		# rented first
		$result | Sort-Object { [bool]$_.status.rented } -Descending | ForEach-Object {
			$Pool_Algorithm = Get-MRRAlgo $_.type
			# $_ | Add-Member Algorithm $Pool_Algorithm
			if ($Pool_Algorithm -and [Config]::ActiveTypes.Length -gt 0 -and $Cfg.DisabledAlgorithms -notcontains $Pool_Algorithm) {
				$KnownTypes = $KnownAlgos.Keys | ForEach-Object { if ($KnownAlgos[$_].ContainsKey($Pool_Algorithm)) { $_ } }
				# (($KnownAlgos.Values | Where-Object { $_.ContainsKey($Pool_Algorithm) } | Select-Object -First 1) | Select-Object -First 1) -ne $null
				# Write-Host "$Pool_Algorithm known types $($KnownTypes) $($KnownTypes.Length) $rented_types"
				if ($KnownTypes.Length -gt 0 -and (($rented_types | Where-object { $KnownTypes -contains $_ }) | Select-Object -first 1) -eq $null) {
					$enabled_ids += $_.id
				}
				else {
					$disable_ids += $_.id
				}
				$Profit = [decimal]$_.price.BTC.price / [MultipleUnit]::ToValueInvariant("1", $_.price.type.ToLower().TrimEnd("h"))
				$user = "$($whoami.username).$($_.id)"
				# possible bug - algo unknown, but rented
				if ($_.status.rented) {
					$rented_ids += $_.id
					$global:MRRRented += $_.id
					$KnownTypes | ForEach-Object {
						$rented_types += $_
					}
					# $redir = Ping-MRR $false $server.name $server.port $user $_.id
					$info = [SummaryInfo]::Elapsed([timespan]::FromHours($_.status.hours))
					$redir =  $mrr.Get("/rig/$($_.id)/port")
					$Algos[$Pool_Algorithm] = [PoolAlgorithmInfo]@{
						Name = $PoolInfo.Name
						Algorithm = $Pool_Algorithm
						Profit = $Profit * 0.97
						Info = $info
						Protocol = "stratum+tcp"
						Hosts = @($redir.server)
						Port = $redir.port
						PortUnsecure = $redir.port
						User = $user
						Password = "x"
						Priority = [Priority]::Unique
					}
					if (![Config]::MRRRented) {
						Write-Host "MRR: Rented $Pool_Algorithm for $info`: $($_.name)" -ForegroundColor Yellow
					}
				}
				else {
					$info = [string]::Empty
					if ($Algos.ContainsKey($Pool_Algorithm)) {
						$info = $Algos[$Pool_Algorithm].Info
					}
					$Algos[$Pool_Algorithm] = [PoolAlgorithmInfo]@{
						Name = $PoolInfo.Name
						Algorithm = $Pool_Algorithm
						Profit = $Profit * 0.97
						Info = $info
						Protocol = "stratum+tcp"
						Hosts = @($server.name)
						Port = $server.port
						PortUnsecure = $server.port
						User = $user
						Password = "x"
						Priority = [Priority]::None
					}
				}
			}
			else {
				$disable_ids += $_.id
			}
		}

		$Algos.Values | ForEach-Object {
			$PoolInfo.Algorithms.Add($_)
		}

		[Config]::MRRRented = $rented_ids.Length -gt 0
		
		# on first run skip enable/disable
		if (($KnownAlgos.Values | Measure-Object -Property Count -Sum).Sum -gt 0) {
			# disable
			$dids = @()
			$result | Where-Object { $_.available_status -match "available" -and $disable_ids -contains $_.id } | ForEach-Object {
				$alg = Get-MRRAlgo $_.type
				Write-Host "MRR: Disable $alg`: $($_.name)" -ForegroundColor Yellow
				$_.available_status = "disabled"
				$dids += $_.id
			}
			if ($dids.Length -gt 0) {
				$mrr.Put("/rig/$($dids -join ';')", @{ "status" = "disabled" })
			}
			# enable
			$eids = @()
			$result | Where-Object { $_.available_status -notmatch "available" -and $enabled_ids -contains $_.id -and $disable_ids -notcontains $_.id } | ForEach-Object {
				$alg = Get-MRRAlgo $_.type
				Write-Host "MRR: Available $alg`: $($_.name)" -ForegroundColor Yellow
				$_.available_status = "available"
				$eids += $_.id
			}
			if ($eids.Length -gt 0) {
				$mrr.Put("/rig/$($eids -join ';')", @{ "status" = "enabled" })
			}
			# ping
			$result | Where-Object { !$_.status.rented -and $enabled_ids -contains $_.id -and $disable_ids -notcontains $_.id } | ForEach-Object {
				$alg = Get-MRRAlgo $_.type
				# Write-Host "$($_ | ConvertTo-Json -Depth 10 -Compress)"
				$KnownTypes = $KnownAlgos.Keys | ForEach-Object { if ($KnownAlgos[$_].ContainsKey($alg)) { $_ } }
				$SpeedAdv = $_.hashrate.advertised.hash * [MultipleUnit]::ToValueInvariant("1", $_.hashrate.advertised.type.ToLower().TrimEnd("h"))
				$Price = [decimal]$_.price.BTC.price / [MultipleUnit]::ToValueInvariant("1", $_.price.type.ToLower().TrimEnd("h"))
				$SpeedCalc = (($KnownAlgos.Values | Foreach-Object { $t = $_[$alg]; if ($t) { $t } }) | Measure-Object Speed -Sum).Sum
				$warn = if ($SpeedCalc * 0.95 -gt $SpeedAdv -or $SpeedCalc * 1.05 -lt $SpeedAdv) { " !~= $([MultipleUnit]::ToString($SpeedCalc)) " } else { [string]::Empty }
				Write-Host "MRR: Online $alg ($(Get-Join ", " $KnownTypes)) ($([decimal]::Round($SpeedAdv * $Price, 8)) at " -NoNewline
				if (![string]::IsNullOrWhiteSpace($warn)) {
					Write-Host "$($_.hashrate.advertised.nice)$warn`H/s" -NoNewline -ForegroundColor Red
				} else {
					Write-Host "$($_.hashrate.advertised.nice)$warn`H/s" -NoNewline
				}
				Write-Host ", $($_.minhours)-$($_.maxhours)h, $($_.region)): $($_.name)"
				Ping-MRR $server.name $server.port "$($whoami.username).$($_.id)" $_.id
			}
			# show top 3
			# $Algos.Values | Where-Object { $_.Profit -eq 0 -and [decimal]$_.Password -gt 20 } | Sort-Object { [decimal]$_.Password } -Descending | Select-Object -First 10 | ForEach-Object {
			# 	Write-Host "Check algo $($_.Algorithm) rented: $("{0:N1}" -f [decimal]$_.Password)% $($_.Info)"
			# }
		}
	}
	else {
		if ([Config]::ActiveTypes.Length -gt 0) {
			Write-Host "MRR: No compatible rigs found! Write `"$($Config.WorkerName)`" key string to MRR rig name." -ForegroundColor Yellow
		}
	}

	if ([Config]::ActiveTypes.Length -gt 0 -and ($KnownAlgos.Values | Measure-Object -Property Count -Sum).Sum -gt 0) {
		$sumprofit = (($KnownAlgos.Values | ForEach-Object { ($_.Values | Where-Object { $_ -and $_.Profit -gt 0 } | Measure-Object Profit -Maximum) }) |
			Measure-Object -Property Maximum -Sum).Sum
		if ($global:HasConfirm) {
			Write-Host "Rig overall profit: $([decimal]::Round($sumprofit, 8))"
		}
		[bool] $save = $false
		$Algos.Values | Where-Object { $Cfg.DisabledAlgorithms -notcontains $_.Algorithm } | ForEach-Object {
			$Algo = $_
			$KnownTypes = $KnownAlgos.Keys | ForEach-Object { if ($KnownAlgos[$_].ContainsKey($Algo.Algorithm)) { $_ } }
			if ($KnownTypes.Length -gt 0) {
				$persprofit = ((($KnownAlgos.Keys | Where-Object { $KnownTypes -contains $_ } | ForEach-Object { $KnownAlgos[$_] }) |
					ForEach-Object { ($_.Values | Where-Object { $_ -and $_.Profit -gt 0 } | Measure-Object Profit -Maximum) }) | Measure-Object -Property Maximum -Sum).Sum *
						(100 + $Cfg.Target) / 100
				# Write-Host "$($Algo.Algorithm) Profit rig $([decimal]::Round($sumprofit, 8)), alg $([decimal]::Round($persprofit, 8))"
				$Speed = (($KnownAlgos.Values | ForEach-Object { $t = $_[$Algo.Algorithm]; if ($t) { $t } }) | Measure-Object Speed -Sum).Sum
				$Profit = $Speed * $Algo.Price
				if ($Algo.Profit -eq 0 -and $Profit -gt 0<#-and [decimal]$Algo.Password -gt 0#>) {
					Write-Host "$($Algo.Algorithm) ($(Get-Join ", " $KnownTypes)) profit is $([decimal]::Round($Profit, 8)), rented $("{0:N1}" -f [decimal]$_.Password)% $($Algo.Info)"
					if ($global:HasConfirm) {
						if (Get-Question "Add rig to MRR for algorithm '$($Algo.Algorithm)'") {
							$prms = @{
								"name" = "$($whoami.username) $($Config.WorkerName) under MindMiner"
								"hash" = @{ "hash" = $Speed; "type" = "hash" }
								"type" = $Algo.User
								"server" = $server.name
								"minhours" = $Cfg.MinHours
								"maxhours" = $Cfg.MaxHours
								"status" = $(if ([Config]::MRRRented) { "disabled" } else { "enabled" })
								"price" = @{ "type" = "hash"; "btc" = @{ "price" = $Algo.Price } }
							}
							if ($Cfg.Wallets) {
								$Cfg.Wallets | Where-Object { [Config]::MRRWallets -contains $_ } | ForEach-Object {
									$prms.price."$_" = @{ "enabled" = $true; "autoprice" = $true }
								}
							}
							$mrr.Put("/rig", $prms)
						}
						else {
							$Cfg.DisabledAlgorithms += $Algo.Algorithm
							$save = $true
						}
					}
					else {
						$global:NeedConfirm = $true
					}
				}
				else {
					# if ($Algo.Profit -gt 0)
					# find rig
					$global:MRRHour = $true
					$rig = ($result | Where-Object { (Get-MRRAlgo $_.type) -eq $Algo.Algorithm }) | Select-Object -First 1
					if ($rig -and !$rig.status.rented -and $rig.available_status -match "available") {
						$SpeedAdv = [decimal]$rig.hashrate.advertised.hash * [MultipleUnit]::ToValueInvariant("1", $rig.hashrate.advertised.type.ToLower().TrimEnd("h"))
						$prft = $SpeedAdv * [decimal]$rig.price.BTC.price / [MultipleUnit]::ToValueInvariant("1", $rig.price.type.ToLower().TrimEnd("h"))
						# Write-Host "MRR: Check profit $($Algo.Algorithm) ($(Get-Join ", " $KnownTypes)) $([decimal]::Round($prft, 8)) grater $([decimal]::Round($persprofit, 8))"
						if ($PrevRented -contains $rig.id -and !$rig.status.rented) {
							$persprofit = $prft * (100 + $Cfg.Increase) / 100
						}
						elseif ($global:MRRHour -and ($prft * (100 - $Cfg.Decrease) / 100) -gt $persprofit) {
							$persprofit = $prft * (100 - $Cfg.Decrease) / 100
						}
						elseif ($prft -lt $persprofit) {
							$persprofit *= 1.01
						}
						elseif ($prft -gt ($persprofit * 10)) {
							$persprofit *= 9.99
						}
						else {
							$persprofit = 0
						}
						[decimal] $prc = $persprofit / $SpeedAdv * [MultipleUnit]::ToValueInvariant("1", $rig.price.type.ToLower().TrimEnd("h"))
						if ($prc -gt 0) {
							Write-Host "MRR: Update $($Algo.Algorithm) ($(Get-Join ", " $KnownTypes)) price from $($rig.price.BTC.price) to $([decimal]::Round($prc, 8)) and profit from $([decimal]::Round($prft, 8)) to $([decimal]::Round($persprofit, 8))" -ForegroundColor Yellow
							$prms = @{
								"price" = @{ "type" = $rig.price.type; "btc" = @{ "price" = $prc; } }
								"minhours" = $Cfg.MinHours
								"maxhours" = $Cfg.MaxHours
							}
							# Write-Host ($prms | ConvertTo-Json -Depth 10)
							$mrr.Put("/rig/$($rig.id)", $prms)
							# Write-Host "$res $($res.price) $($res.price.BTC)"
						}
					}
				}
			}
		}
		if ($save) {
			[BaseConfig]::Save($configpath, $Cfg)
		}
		$global:MRRHour = $false
	}

	# info as standart pool
	$PoolInfo.HasAnswer = $true
	$PoolInfo.AnswerTime = [DateTime]::Now
}
catch {
	Write-Host $_
}
finally {
	if ($mrr) {	$mrr.Dispose() }
}

return $PoolInfo
