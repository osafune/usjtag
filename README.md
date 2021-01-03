# usjtag
FTDI USBシリアル変換（FT230X/FT231X/FT234XD）を使って、Intel FPGAの内部JTAGハブ（SLD Hub）へのアクセスを提供します。PCからはUSB-Blaster互換のJTAGダウンロードケーブルとして識別されます。  
また、CycloneデバイスではSerial Flash Loaderオプションを使用してコンフィグレーションROMの書き換えをサポートします。  
- **メリット**
	- デバイスのハードウェアJTAG端子を使用せずにNiosII gdbやSignalTapII、Virtual JTAGインスタンスへアクセスが可能です
	- 外部ピンはRXD/TXDの2本のみ
	- QuartusやNiosII SBTからはUSB-Blasterとして識別されます
	- 絶縁UARTモジュールを使用することでUL-1577,CA5A準拠のJTAGデバッガを構築できます
- **デメリット**
	- 接続先は仮想JTAGデバイスのため、ピンの走査やFPGAコンフィギュレーション等、ハードウェアの直接制御はできません
	- 接続は2Mbpsの調歩同期なのでJTAG転送レートは遅くなります

- 実行環境
	- Quartus Prime 17.1以降


# License
The MIT License (MIT)  
Copyright (c) 2020 J-7SYSTEM WORKS LIMITED.

# How to use
### 基本的な使い方
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
* 上記操作をしてもProgrammerからUSB-Blasterとして認識されない場合。
	1. デバイスマネージャーを開いて `ユニバーサル シリアル バス コントローラー` 以下にある `USB Serial Converter` を右クリック→ `ドライバーの更新` を選択
	2. `コンピューターを参照してドライバーソフトウェアを検索` を選択
	3. `コンピューター上の利用可能なドライバーの一覧から選択します` を選択
	4. `☑ 互換性のあるハードウェアを表示` のチェックを外す
	5. 製造元リストから `Altera` を選択し、モデルのリストから `Altera USB-Blaster` を選択して `次へ` をクリック
	6. ドライバーの更新警告に `はい` を選択
	7. Quartus Prime ProgrammerからUSB-Blasterとして認識されているのを確認します
	8. デバイスマネージャーでは一時的に `Altera USB-Blaster` になっているので、右クリック→ `ドライバーの更新` を選択
	9. `ドライバーソフトウェアの最新版を自動検索` を選択して、ドライバーを元に戻します
<br>

### インスタンスオプション
|パラメータ名|タイプ|デフォルト値|説明|
|---|---|---|---|
|DEVICE_FAMILY|string|"Cyclone IV E"|デバイスファミリー名を文字列で指定します。以下のデバイスが指定できます。<br>"Cyclone IV E"<br>"Cyclone IV GX"<br>"Cyclone 10 LP"<br>"Cyclone V"<br>"MAX 10"|
|CLOCK_FREQUENCY|integer|50000000|clockポートに入力するクロック周波数を指定します。値は16000000(16MHz)以上で2000000(2MHz)の倍数値でなければなりません。|
|USE_SERIAL_FLASH_LOADER|string|"OFF"|Serial Flash Loaderを同時にインスタンスする場合には"ON"を指定します。Serial Flash LoaderはCycloneデバイスファミリーでのみインスタンスできます。|

例) Cyclone10LPでSFLを使う場合
```verilog
usjtag #(
	.DEVICE_FAMILY ("Cyclone 10 LP"),
	.USE_SERIAL_FLASH_LOADER ("ON")
)
usjtag_inst (
	.reset	(~RESET_N),
	.clock	(CLOCK50),	// 50MHzのクロックを入力 
	.ft_rxd	(RXD),		// FT234XのTXDから
	.ft_txd	(TXD),		// FT234XのRXDへ
	.sfl_enable (1'b1)	// SFL有効
);
```
SFL経由でコンフィグレーションROMを書き換える場合は、書き込みたいコンフィグレーションのjicファイルを作成した後、QuartusProgrammerではデバイス側のconfigureチェックを外しROM側のみにチェックを入れて書き込みを行います。

