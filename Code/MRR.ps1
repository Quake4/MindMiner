class MRR <#: System.IDisposable#> {
	hidden [string] $Root = "https://www.miningrigrentals.com/api/v2";
	hidden [string] $Agent = "MindMiner-MRR/1.0";
	hidden [string] $Key;
	hidden [string] $Secret;
	hidden [Security.Cryptography.HMACSHA1] $HMACSHA1;
	
	[int] $Timeout;
	[bool] $Debug = $false;

	MRR([string] $key, [string] $secret) {
		$this.Init($key, $secret, 15)
	}

	MRR([string] $key, [string] $secret, [int] $timeout) {
		$this.Init($key, $secret, $timeout)
	}

	hidden [void] Init([string] $key, [string] $secret, [int] $timeout) {
		$this.Key = $key;
		$this.Secret = $secret;
		$this.Timeout = $timeout;
		$this.HMACSHA1 = [Security.Cryptography.HMACSHA1]::Create();
		$this.HMACSHA1.Key = [Text.Encoding]::UTF8.GetBytes($secret);
	}

	hidden [PSCustomObject] Query([string] $type, [string] $endpoint, [hashtable] $params) {

		$url = if ($endpoint -like "?") { $spl = $endpoint.Split("?"); $endpoint = $spl[0]; "$($spl[0])$($spl[1])" } else { "$($this.Root)$endpoint" }

		$result = $null;
		1..5 | ForEach-Object {
			if (!$result) {
				$nonce = [datetime]::UtcNow.Ticks
				$headers = [hashtable]@{
					"x-api-sign" = [BitConverter]::ToString($this.HMACSHA1.ComputeHash([Text.Encoding]::UTF8.Getbytes("$($this.Key)$nonce$endpoint"))).Replace("-", "").ToLower()
					"x-api-key" = $this.Key
					"x-api-nonce" = $nonce
				};
				try {
					$body = if ($params -or $params.Count -gt 0) { $params | ConvertTo-Json -Compress } else { $null }
					$result = Invoke-RestMethod $url -Method $type -Headers $headers -Body $body -UserAgent $this.Agent -TimeoutSec $this.Timeout -ContentType "application/json" -UseBasicParsing
				}
				catch {
					if ($_.Exception -is [Net.WebException] -and ($_.Exception.Response.StatusCode -eq 503 -or $_.Exception.Response.StatusCode -eq 449)) {
						Start-Sleep -Seconds 15
					}
				}
			}
		}
		if (!$result -or ($result -and !$result.success)) {
			throw [Exception]::new("MRR query isn't sucess: $endpoint");
		}
		if ($this.Debug -and $result) {
			Write-Host "$type $endpoint`: $($result.data | ConvertTo-Json -Compress | Out-String)"
		}
		return $result.data;
	}

	[PSCustomObject] Get([string] $endpoint) {
		return $this.Query("GET", $endpoint, $null);
	}

	[PSCustomObject] Get([string] $endpoint, [hashtable] $params) {
		return $this.Query("GET", $endpoint, $params);
	}

	[PSCustomObject] Post([string] $endpoint, [hashtable] $params) {
		return $this.Query("POST", $endpoint, $params);
	}

	[PSCustomObject] Put([string] $endpoint, [hashtable] $params) {
		return $this.Query("PUT", $endpoint, $params);
	}

	[PSCustomObject] Delete([string] $endpoint) {
		return $this.Query("DELETE", $endpoint, $null);
	}

	[PSCustomObject] Delete([string] $endpoint, [hashtable] $params) {
		return $this.Query("DELETE", $endpoint, $params);
	}

	[void] Dispose() {
		if ($this.HMACSHA1) {
			$this.HMACSHA1.Dispose();
			$this.HMACSHA1 = $null;
		}
	}
};

function Ping-MRR ([Parameter(Mandatory)][string] $Server, [Parameter(Mandatory)][int] $Port, [Parameter(Mandatory)][string] $User, [Parameter(Mandatory)][string][string] $rigid) {
	# [Parameter(Mandatory)][bool] $ping, 
	$request = @()
	#if ($ping) {
		$request += @{ "id" = 1; "method" = "login"; "params"= @{ "login" = $User; "pass" = "x"; "rigid" = $rigid } } | ConvertTo-Json -Compress
	#}
	#else {
	#	$request += "{`"id`":1,`"method`":`"mining.authorize`",`"params`":[`"$User`",`"$Pass`"]}"
	#	$request += "{`"id`":2,`"method`":`"mining.extranonce.subscribe`",`"params`":[]}"
	#}

	try {
		$Client = [Net.Sockets.TcpClient]::new($Server, $Port)
		$Client.ReceiveTimeout = $Client.SendTimeout = 15 * 1000
		$Stream = $Client.GetStream()
		$Stream.ReadTimeout = $Stream.WriteTimeout = 15 * 1000;
		$Writer = [IO.StreamWriter]::new($Stream)
		#$Reader = [IO.StreamReader]::new($Stream)

		$request | ForEach-Object {
			$Writer.WriteLine($_)
			$Writer.Flush()
			<#$result = $Reader.ReadLine()
			if ($_ -match "mining.extranonce.subscribe") {
				$result = $result | ConvertFrom-Json
				if (!$result.error -and $result.method -eq "client.reconnect") {
					$result.params
				}
			}#>
		}
	}
	catch {
		Write-Host "Ping $Server`:$Port error: $_" -ForegroundColor Red
	}
	finally {
		#if ($Reader) { $Reader.Dispose(); $Reader = $null }
		if ($Writer) { $Writer.Dispose(); $Writer = $null }
		if ($Stream) { $Stream.Dispose(); $Stream = $null }
		if ($Client) { $Client.Dispose(); $Client = $null }
	}
}