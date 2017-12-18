# MindMiner
### *by Oleg Samsonov aka Quake4*

Miner manager programm.
Support CPU mining and mining on nVidia cards.

### Coming soon
* AMD support
* Dual mining

## Features
* Very small size ~50Kb
* Low memory use ~50Mb
* Self update
* No memory leak
* Small CPU usage
* Fast switch for most profit algo/coin
* Very configurable

## Support
### Pools ([full list](https://github.com/Quake4/MindMiner/tree/master/Pools))
* NiceHash
* MinigPoolHub
* Zpool

### Miners ([full list](https://github.com/Quake4/MindMiner/tree/master/Miners))
* cpuminer-opt
* ccminer
* ewbf
* nheqminer

## Requirements
Windows 10/7 x64 (Support 32Bit, but many miners support only 64x)

Please install:
* Visual C++ Redistributable 2015 https://www.microsoft.com/en-US/download/details.aspx?id=48145
* Visual C++ Redistributable 2013 https://www.microsoft.com/en-US/download/details.aspx?id=40784
* ~~Visual C++ Redistributable 2012 https://www.microsoft.com/en-US/download/details.aspx?id=30679~~

If use CPU mining please [allow lock page support](https://docs.microsoft.com/en-us/sql/database-engine/configure-windows/enable-the-lock-pages-in-memory-option-windows) in OS to double XMR profit.

## Install
Download [latest release](https://github.com/Quake4/MindMiner/releases) to any folder. Unpack and may create `config.txt` (see config section) or just run "run.bat" and enter BTC wallet and other data asked data.

## Config
Place `config.txt` file into programm folder with content
```json
{
    "Wallet":  {
                   "BTC":  "YOUR BTC WALLET"
               },
    "WorkerName": "Rig/Computer Name",
    "Login": "Login for Pool with registration"
}
```

## Fee
MindMiner has development fee ~~1% and~~ in all benchmarks.

## Thanks
Thanks to aaronsace to the idea but poor realization.
