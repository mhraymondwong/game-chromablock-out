# 彩色方塊逃脫 Color Block Escape

原創兒童向滑塊益智遊戲（Godot 4.7）。玩法靈感來自滑塊逃脫類遊戲（如 Rush Hour 類型），**美術、關卡、名稱與文案皆為原創**，未使用任何商業遊戲素材。

## 怎麼玩

1. 把**彩色方塊**滑到**同顏色的門**，讓它們離開棋盤。
2. 滑鼠拖曳，或先點選再用方向鍵／WASD。
3. **Z** 復原、**H** 提示。
4. 灰色石頭是障礙，不會離開。
5. 有 ↔／↕ 的方塊只能橫向或直向移動。
6. 結冰方塊要等其他顏色先逃脫才會解凍。
7. 清空所有彩色方塊即過關（石頭可留下）。

## 操作需求

- Godot **4.7**（本機路徑範例：`/home/box/bin/godot`）
- 解析度 1280×720

```bash
cd "/workspace/agents/Game Designer/color-block-escape"
/home/box/bin/godot --path . --display-driver x11 --rendering-driver opengl3
```

## 測試

```bash
/home/box/bin/godot --headless --path . --script res://tools/smoke_test.gd
/home/box/bin/godot --headless --path . --quit-after 2
```

## 關卡

內建 **8** 關，依序解鎖。每關有標準步數（par）與金牌時間。

## 授權

程式與原創美術由專案作者製作。字型使用 Noto Sans CJK（SIL Open Font License）。
