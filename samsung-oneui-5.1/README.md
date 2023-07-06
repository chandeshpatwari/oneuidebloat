# Debloat and Optimise

## Debloat
List Generated with [`[UAD]`](https://github.com/0x192/universal-android-debloater)

- Safe to uninstall

### Samsung Services
```
## Required by many apps
com.osp.app.signin

## Samsung Members, trash
com.samsung.android.voc

## Samsung Pass, better login managers available
com.samsung.android.samsungpass
com.samsung.android.samsungpassautofill
com.samsung.android.authfw

## Samsung Cloud, removal breaks "Cloud Backup"
com.samsung.android.scloud

## Find my phone, pretty useful
com.samsung.android.fmm

## Call & text on another devices(samsung galaxy), idk
com.samsung.android.mdecservice

## Samsung Visit in, trash
com.samsung.android.ipsgeofence

## Group Sharing, idk
com.samsung.android.mobileservice

```
### Samsung apps
```
## Samsung Health
com.sec.android.app.shealth
com.samsung.klmsagent

## Bixby, bloat
com.samsung.android.bixby.agent

# Samsung Wallet, idk
com.samsung.android.spay
com.samsung.android.spayfw

## Samsung Internet
com.sec.android.app.sbrowser

## Galaxy Wearable, bloat
com.samsung.android.app.watchmanager
com.samsung.android.app.watchmanagerstub

## SmartThings, bloat
com.samsung.android.oneconnect
com.samsung.android.easysetup
com.samsung.android.beaconmanager
com.samsung.android.ststub

## Galaxy Store
com.sec.android.app.samsungapps

## Penup
com.sec.penup
```

### Connected Devices
```
## Continue apps on other devices
com.samsung.android.mcfserver
com.samsung.android.mcfds

## Multi Control
com.samsung.android.inputshare

## Smart View
com.samsung.android.smartmirroring
```
### Other
```
# Breaks "Connections > Mobile Hotspot and Tethring > Mobile Hotspot > Auto Hotspot"
com.sec.mhs.smarttethering

# Breaks "Modes and Routines" location based tigger
com.sec.location.nsflp2
com.samsung.android.location

# Breaks "Advanced features > Motion and Gestures > Keep Screen on While Viewing"
com.samsung.android.smartface
com.samsung.android.smartface.overlay

## Removes "Digital wellbeing and parental controls, Driving& Walking Monitor", bloat
com.samsung.android.rubin.app

## Removes "Battery and Device care -> Device Protection"
com.samsung.android.sm.devicesecurity

## Removes "Battery and Device care -> Ultra Data Saving"
com.samsung.android.uds

## Removes "Sticker Option in OEM Keyboard"
com.samsung.android.stickercenter

```


### Apps that lack description in [`[UAD]`](https://github.com/0x192/universal-android-debloater)
- Break significant features, but can be uninstalled


- Unknown functionality but seem important
```
com.sec.location.nfwlocationprivacy
com.samsung.android.container
com.samsung.android.wifi.p2paware.resources
com.sec.usbsettings
com.skms.android.agent
```

- **Unsafe to uninstall** : Apps that are not listed or marked such in [`[UAD]`](https://github.com/0x192/universal-android-debloater)
