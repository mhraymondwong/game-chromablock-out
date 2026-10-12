# 彩色方塊逃脫 Color Block Escape

原創兒童向滑塊益智遊戲（Godot 4.7）。玩法靈感來自滑塊逃脫類遊戲（如 Rush Hour 類型），**美術、關卡、名稱與文案皆為原創**，未使用任何商業遊戲素材。

## 怎麼玩

1. 把**彩色方塊**滑到**同顏色的門**，讓它們離開棋盤。
2. **觸控／滑鼠拖曳**，或先點選再用方向鍵／WASD。
3. **Z** 復原、**H** 提示（手機用底部工具列）。
4. 灰色石頭是障礙，不會離開。
5. 有 ↔／↕ 的方塊只能橫向或直向移動。
6. 結冰方塊要等其他顏色先逃脫才會解凍。
7. 清空所有彩色方塊即過關（石頭可留下）。

## 美術（兒童風格 UI）

- **開始畫面**：Raymond 繪製的開場圖 `assets/ui/start_page.png`（全螢幕 cover）；點橙色 **PLAY**（或畫面下半）進入規則說明，再按「開始遊戲！」進入關卡。
- **標題 Logo**：自開場圖裁出的 `assets/ui/logo.png`，用作遊戲內頂部標題（取代舊的程序生成 title_banner）。
- 其餘程序生成圖組（`tools/gen_ui_art.py` → `assets/ui/`）：粉彩玩具房背景、彩色 HUD 徽章、大圓形圖示按鈕、星星。介面以圖示為主，必要處保留繁中說明。

```bash
python3 tools/gen_ui_art.py
```

## 直式手機介面（Portrait only）

- 伸縮模式：`canvas_items` + `expand`；預設視口 **390×844**。
- **僅直式**：`window/handheld/orientation=portrait`；無論視窗多寬都用「標題＋徽章＋棋盤＋底部大按鈕」版面。
- 兒童風標題橫幅、彩色關卡／時間／步數／分數徽章、底部約 **72–88px** 圓形圖示按鈕（復原／重來／提示／地圖／規則）。
- 背景全螢幕玩具房天空；已啟用觸控／滑鼠雙向模擬。

## 操作需求

- Godot **4.7**（本機路徑範例：`/home/box/bin/godot`）

```bash
cd "/workspace/agents/Game Designer/color-block-escape"
/home/box/bin/godot --path . --display-driver x11 --rendering-driver opengl3
```

## 測試

```bash
/home/box/bin/godot --headless --path . --script res://tools/smoke_test.gd
/home/box/bin/godot --headless --path . --quit-after 2
```

## 匯出 Android（之後）

1. 在 Godot 編輯器：**Editor → Manage Export Templates**，安裝與引擎版本相符的範本。
2. **Project → Export → Add… → Android**。
3. 設定 package 名稱（例如 `com.yourname.colorblockescape`）、圖示與權限（此遊戲不需特殊權限）。
4. 安裝 Android SDK／JDK，並在匯出預設中填好 debug keystore（或正式簽章）。
5. **Export Project** 產出 `.apk` 或 `.aab`。  
   CLI 範例（需先在編輯器存好 export preset）：

```bash
/home/box/bin/godot --headless --path . --export-debug "Android" build/color-block-escape-debug.apk
```

iOS 需在 macOS + Xcode 上同樣用 Export 預設匯出。

## 關卡

內建 **8** 關，依序解鎖。每關有標準步數（par）與金牌時間。

## 授權

程式與原創美術由專案作者製作。字型使用 Noto Sans CJK（SIL Open Font License）。
