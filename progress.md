# Progress

## M1 地圖與鏡頭（2026-10-22）
- 完成：Vite + TS + Phaser 3.90 骨架；`src/sim/map/` 地形/高度解析、據點/總部/橋分組、比例尺量測與裁切、8×8 多數縮圖、公尺↔格換算
- 完成：`src/render/` 開發用幾何風格包、地形繪製（高度明暗＋等高線）；`src/input/CameraController.ts` 鏡頭；HUD 顯示游標格的地形與高度
- 測試：22/22（河城高度圖 (91,104) 由 3 改為 2，消除懸崖，使用者同意）
- 已推到 GitHub PeanutGT/tactical-commands-frontlines 的 main

## 未實測
- 觸控：單指拖曳平移、雙指縮放（只在桌面瀏覽器測過滾輪縮放與 WASD）
- 中鍵拖曳、空白鍵＋左鍵拖曳、邊緣捲動
- 手機瀏覽器實機

## 待做（M1 剩餘）
- 匯入工具 `scripts/import-map.ts`（量比例尺、縮圖、輸出 map.json），可延到第二張地圖時做
