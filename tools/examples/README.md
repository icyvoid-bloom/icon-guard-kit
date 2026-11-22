# examples

本目录**不存放任何图片**。图标成品与参考图属于使用者自己的素材，不入库。

自测时把一张方图放在本目录，然后：

```powershell
python ..\build_ico.py `
  --input .\your_art.png `
  --output .\your_app.ico `
  --text "Your App" `
  --head-x 0.47 --head-y 0.48 --face-crop 0.36 `
  --emit-png
```

产物（`.ico`、`*_1024.png`、`*_16.png` 等）已被 `.gitignore` 忽略，可放心本地留存。
