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

原創程序生成圖組（`tools/gen_ui_art.py` → `assets/ui/`）：粉彩玩具房背景、標題橫幅、圓形光澤圖示按鈕（復原／重來／提示／地圖／規則）、星星與側欄框。介面以圖示為主，必要處保留繁中說明（規則彈窗等）。

```bash
python3 tools/gen_ui_art.py
```

## 響應式／手機

- 伸縮模式：`canvas_items` + `expand`（依視窗長寬比擴充可用空間）。
- **直式手機**（窄螢幕）：棋盤置中放大，側欄改為**底部工具列**（復原／重來／提示／地圖／規則），觸控目標 ≥44px。
- **橫式／平板／桌面**：右側面板＋說明文字。
- 已啟用 `emulate_touch_from_mouse` 與 `emulate_mouse_from_touch`；手持裝置方向設為 **sensor**（可隨旋轉切換直橫）。
- HUD、彈窗與關卡地圖會依視口自動重排。

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
