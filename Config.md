# Сonfiguration manual of MindMiner
Any configuration stored in json format.

## MindMiner config
MindMiner settings placed in config.txt file into root application folder.

Main settings file is read only at the start of the MindMiner. If configuration file is absent or has wrong json format MindMiner ask your wallet and create default config.

```json
{
    "Region": "Europe",
    "SSL": true,
    "Wallet": { "BTC": "BTC Wallet" },
    "WorkerName": "Worker name",
    "Login": "Login",
    "Password": "x",
    "CheckTimeout": 5,
    "LoopTimeout": 60,
    "NoHashTimeout": 10,
    "AverageCurrentHashSpeed": 180,
    "AverageHashSpeed": "1 day",
    "Verbose": "Normal",
    "ShowBalance": true,
    "AllowedTypes": [ "CPU", "nVidia", "AMD", "Intel" ],
    "Currencies": { "BTC": 8, "USD": 2, "EUR": 2 },
    "CoolDown": 0,
    "ApiServer": false,
    "SwitchingResistance": { "Enabled": true, "Percent": 4, "Timeout": 15 },
    "BenchmarkSeconds": { "CPU": 60, "nVidia": 240 },
	"MinimumMiners": 5
}
```

* ***Region*** [enum] (**Europe**|Usa|China|Japan|Other) - pool region.
* ***SSL*** [bool] (**true**|false) - use secure protocol if possible.
* **Wallet** [key value collection] - coin wallet addresses (now support one or two wallets: `BTC` and/or `LTC`):
    * **Key** [string] - coin short name (if specified `"LTC"` wallet its use at Zergpool, HashRefinery and BlockMasters).
    * **Value** [string] - coin wallet address.
* ***WorkerName*** [string] - worker name. If empty use machine name.
* **Login** [string] - login for pool with registration (MiningPoolHub).
* ***Password*** [string] - password. If empty default value `"x"`.
* ***CheckTimeout*** [int] - check timeout in seconds for read miner speed. Recomended value from 3 seconds to 15 secounds.
* ***LoopTimeout*** [int] - loop timeout in second. Recomended value from 30 seconds to five minute.
* ***NoHashTimeout*** [int] - timeout in minutes to disable miner after determining zero hash.
* ***ShowBalance*** [bool] - show balance if value equal true, else dont show.
* ***AverageCurrentHashSpeed*** [int] - miner average current hash speed in seconds. Recomended value from 120 second to five minute.
* ***AverageHashSpeed*** [string] - miner average hash speed in  [time interval](https://github.com/Quake4/HumanInterval/blob/master/README.md). Recomeded value from few hours to one day.
* ***Verbose*** [enum] (Full|**Normal**|Minimal) - verbose level.
* ***AllowedTypes*** [enum array] (CPU|nVidia|AMD|Intel) - allowed devices to mine.
* ***Currencies*** [key value collection] - currencies for output (maximum supported 3). If empty use by default `{ "BTC": 8, "USD": 2}`:
    * **Key** [string] - currency name from [supported list](https://api.coinbase.com/v2/exchange-rates?currency=BTC) + `mBTC`.
    * **Value** [int] - the number of digits after the decimal point.
* ***CoolDown*** [int] - the number of seconds to wait when switching miners.
* ***ApiServer*** [bool] - start local api server for get api pools info in proxy mode or show MindMiner status.
* ***SwitchingResistance*** [key value collection] - switching resistance. If it is enabled, the switching is performed if the percentage or timeout is exceeded.
    * **Enabled** [bool] (**true**|false) - enable or disable the switching resistance between miners.
    * **Percent** [decimal] (4) - the percentage of switching. Must be a greater then zero.
    * **Timeout** [int] (15) - the switching timeout in minutes. Must be a greater then **LoopTimeout** in munutes.
* ***BenchmarkSeconds*** [key value collection] - global default timeout in seconds of benchmark for device type. If set, it overrides the miner configuration:
    * **Key** [string] - (CPU|nVidia|AMD|Intel) device type.
    * **Value** [int] - timeout in seconds of benchmark.
* ***MinimumMiners*** [int] - minimum number of miners on the pool algorithm to use. Only for yiimp like pools.

## Algorithms
MindMiner algorithms settings placed in algorithms.txt file into root application folder.

Algorithms settings read on each loop. You may change configuration at any time and it will be applied on the next loop. If you delete algorithms config or change to wrong json format it will be created default on the next loop.

```json
{
    "Difficulty": { "X16r": 48, "X16s": 48, "Phi": 128000 },
    "EnabledAlgorithms": [ "Bitcore", "X17", "X16r" ],
    "DisabledAlgorithms": [ "Blake2s" ],
    "RunBefore": { "Ethash": "fastmem.bat" },
    "RunAfter": { "Ethash": "normalmem.bat" }
}
```

* ***Difficulty*** [key value collection] - algorithms difficulties.
    * **Key** [string] - algorithm name.
    * **Value** [decimal] - difficulty value.
* ***EnabledAlgorithms*** [string array] - set of enabled algorithms. If the value is null or empty, this means that all algorithms are enabled from the all pools otherwise only the specified algorithms are enabled on all pools.
* ***DisabledAlgorithms*** [string array] - set of disabled algorithms. Always disables the specified algorithms on all pools.
* ***RunBefore*** [key value collection] - command line to run before start of miner in folder ".\Run". More priority than in the configuration of the miner.
    * **Key** [string] - algorithm name.
    * **Value** [string] - command line.
* ***RunAfter*** [key value collection] - command line to run after end of miner in folder ".\Run". More priority than in the configuration of the miner.
    * **Key** [string] - algorithm name.
    * **Value** [string] - command line.

## Pools
Pools configuration placed in Pools folder and named as pool name and config extension.

Pools settings read on each loop. You may change configuration at any time and it will be applied on the next loop. If you delete pool config or change to wrong json format it will be created default on the next loop after your confirm and answer at console window.

Look like this "PoolName.config.txt".

Any pool has this config (exlude ApiPoolsProxy, see it section):
```json
{
    "AverageProfit": "1 hour 30 min",
    "Enabled": false,
    "EnabledAlgorithms": [ "Bitcore", "X17", "X16r" ],
    "DisabledAlgorithms": null
}
```

* **Enabled** [bool] (true|false) - enable or disable pool for mine.
* **AverageProfit** [string] - averages a profit on the coins at the specified [time interval](https://github.com/Quake4/HumanInterval/blob/master/README.md).
* ***EnabledAlgorithms*** [string array] - set of enabled algorithms. If the value is null or empty, this means that all algorithms are enabled from the pool otherwise only the specified algorithms are enabled.
* ***DisabledAlgorithms*** [string array] - set of disabled algorithms. Always disables the specified algorithms.


### Specific for MiningPoolHub
* ***APiKey*** [string] - api key for get balance on MiningPoolHub. See "Edit Account" section and "API KEY" value in MPH account.

### Specific for NiceHash
* ***Wallet*** [string] - internal NiceHash wallet.

### Specific for ZergPool
* ***SpecifiedCoins*** [array] - specifing preferred coin for algo. (Algo as key and sign of coin as value or array of value for several sign of coins) If add "only" to the array of coin signs, only the specified coin will be used (see `X17` algo and `XVG` sign of coin).

Example:
```json
{
    "AverageProfit": "1 hour 30 min",
    "Enabled": true,
    "SpecifiedCoins": { "NeoScrypt": [ "SPK", "GBX"], "Phi": "LUX", "X17": [ "XVG", "only" ] }
}
```

If algo has two or three conis you must specify one coin. If it coin down then MindMiner to be mine just algo without specified coin (example Phi algo need specify only LUX, not need specify together FLM).
This feature give you a very great opportunity to increase profit.

### ApiPoolsProxy
If you have more then ten rigs, some pools can block api requests because there will be a lot of requests to prevent ddos attacks. For proper operation MindMiner need to use the api pools proxy. Define at least two rigs (Master) to send (Slave) information about the api pools data.
* Change on Master main configuration by adding `"ApiServer": true` (see `MindMiner config` section) and rerun MindMiner as Administrator.
* Change on Slave ApiPoolsProxy configuration: enable it and write names and/or IPs of Master rigs.

Example:
```json
{
    "Enabled": true,
    "ProxyList": [ "rig1", "rig2", "192.168.0.19" ]
}
```

* **Enabled** [bool] (true|false) - enable or disable use api pools proxy.
* **ProxyList** [string array] - set of rig names or IP addresses where to send a request the api pools data.

The Slave rigs will have settings of pools made on the Master rig. In the absence of a response from one Master rig, Slave rig will be switched for the following Master rig in the proxy list.

## Miners
Miners configuration placed in Miners folder and named as miner name and config extension.

Miners settings read on each loop. You may change configuration at any time and it will be applied on the next loop. If you delete miner config or change to wrong json format it will be created default on the next loop.

Look like this "MinerName.config.txt".

Simple miner config:
```json
{
    "Algorithms": [
                       {
                           "ExtraArgs": null,
                           "BenchmarkSeconds": 0,
                           "Enabled": true,
                           "Algorithm": "cryptonight",
                           "RunBefore": "cn.bat 123 345",
                           "RunAfter": "\"..\\..\\My Downloads\\cn.bat\" 123 123"
                       },
                       {
                           "ExtraArgs": "-lite",
                           "BenchmarkSeconds": 0,
                           "Enabled": true,
                           "Algorithm": "cryptolite"
                       }
                   ],
    "ExtraArgs": null,
    "BenchmarkSeconds": 60,
    "Enabled": true
}
```

Xmr-stak-cpu miner config:
```json
{
    "ThreadMask": null,
    "ExtraArgs": null,
    "BenchmarkSeconds": 30,
    "ConfigFile": null,
    "ThreadCount": 3,
    "Enabled": true
}
```

* common:
    * **Enabled** [bool] (true|false) - enable or disable miner.
    * ***ExtraArgs*** [string] - miner extra parameters for all algorithms.
    * ***BenchmarkSeconds*** [int] - default timeout in seconds for benchmark for any algorithm. If not set or zero must be set algorithm BenchmarkSeconds.
* algorithms miners:
    * **Algorithms** [array] - array of miner algorithms.
        * **Enabled** [bool] (true|false) - enable or disable algorithm.
        * **Algorithm** [string] - pool algorithm and miner algorithm parameter.
        * ***DualAlgorithm*** [string] - pool algorithm and miner algorithm parameter for dual mining (only in claymore dual miner).
        * ***ExtraArgs*** [string] - algorithm extra parameters in additional to common ExtraArgs.
        * ***BenchmarkSeconds*** [int] - default timeout in seconds for benchmark for current algorithm. If not set or zero use common BenchmarkSeconds.
        * ***RunBefore*** [string] - full command line to run before start of miner in folder ".\Run".
        * ***RunAfter*** [string] - full command line to run after end of miner in folder ".\Run".
* xmr-stak-cpu miner (must be set value in one parameter or all empty for defaults):
    * **ThreadMask** [string] - array of 0 or 1 of cpu mask to enable or disable thread. Mask "0101" enabled two thread from four.
    * **ConfigFile** [string] - user created filename miner config.
    * **ThreadCount** [int] - thread count.
