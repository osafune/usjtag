# usjtag
FTDI USBシリアル変換（FT230X/FT231X/FT234XD）を使って、Intel FPGAの内部JTAGハブ（SLD Hub）へのアクセスを提供します。PCからはUSB-Blaster互換のJTAGダウンロードケーブルとして識別されます。  
- **メリット**
	- デバイスのハードウェアJTAG端子を使用せずにNiosII gdbやSignalTapII、Virtual JTAGインスタンスへアクセスが可能です
	- 外部ピンはRXD/TXDの2本のみ
	- QuartusやNiosII SBTからはUSB-Blasterとして識別されます
- **デメリット**
	- 接続先は仮想JTAGデバイスのため、ピンの走査やコンフィギュレーション等、ハードウェアの直接制御はできません
	- 2Mbpsの調歩同期で接続されるためJTAG転送速度は遅くなります

# License
The MIT License (MIT)  
Copyright (c) 2020 J-7SYSTEM WORKS LIMITED.

# How to use
1. `HDL`フォルダ以下のファイルをプロジェクトに追加します。
2. プロジェクトのトップエンティティで以下のようにインスタンスします。
```verilog
usjtag
usjtag_inst (
	.reset	(~RESET_N),
	.clock	(CLOCK50),	// 50MHzのクロックを入力 
	.ft_rxd	(RXD),		// FT234XのTXDから
	.ft_txd	(TXD)		// FT234XのRXDへ
);
```
3. FT_Progを使ってFT234XのNVMを以下のように書き換えます。
	- `USB String Descriptors/Product Description` に "USB-Blaster" を設定
	- `Hardware Specific/Port A/Driver` は `D2XX Direct` を選択
