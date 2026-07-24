# Mascot (detective) — 3D source → baked PNG

`detective.glb` is the 3D source for the home-screen mascot (the friendly
detective who "speaks" the daily tip). The built-in speech bubble was stripped
from the original model (we draw our own bubble in Flutter so the tip text
fits any length).

The app does NOT render 3D at runtime — that would need a heavy WebView and the
model has no animation. Instead we bake a transparent PNG and ship that:
`assets/images/mascot/detective.png`.

## Re-bake (new pose / angle / size)
Rendered headless with Google model-viewer + Playwright's Chromium:

1. Serve this folder + `model-viewer.min.js` over http (ES modules need http, not file://).
2. Load `<model-viewer src="detective.glb" environment-image="neutral" exposure="1.2"
   shadow-intensity="0" camera-orbit="12deg 80deg 100%">`.
3. Wait for `modelViewer.loaded`, then element-screenshot with `omitBackground:true`.
4. Trim the transparent bbox and resize to ~420px tall (PIL LANCZOS).

Colours already match the Candy theme (the hat band is teal).
