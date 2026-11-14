"""분리 PNG의 실제 Chromium 재조립·모바일 입력을 검증합니다. 게임·배포를 실행하지 않습니다."""
from contextlib import contextmanager
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from io import BytesIO
from pathlib import Path
import argparse
import hashlib
import json
import threading

import numpy as np
from PIL import Image
from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[1]
KIT = ROOT / "art_sources/ui/kit/rev3"
REFERENCES = ROOT / "art_sources/ui/reference/rev3"


class SilentHandler(SimpleHTTPRequestHandler):
    def log_message(self, *_args):
        pass


@contextmanager
def server():
    # 원화 비교 URL도 읽을 수 있도록 저장소 루트만 로컬 주소로 제공합니다.
    handler = partial(SilentHandler, directory=str(ROOT))
    host = ThreadingHTTPServer(("127.0.0.1", 0), handler)
    thread = threading.Thread(target=host.serve_forever, daemon=True)
    thread.start()
    try:
        yield f"http://127.0.0.1:{host.server_port}/art_sources/ui/kit/rev3/index.html"
    finally:
        host.shutdown()
        host.server_close()
        thread.join()


def source_image(screen):
    image = Image.open(REFERENCES / screen["reference"]).convert("RGB")
    if screen["source_crop"]:
        x, y, width, height = screen["source_crop"]
        image = image.crop((x, y, x + width, y + height))
    return image


def validate(report, chromium):
    report.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((KIT / "portable/manifest.json").read_text(encoding="utf-8"))
    assert hashlib.sha256((KIT / "layouts.json").read_bytes()).hexdigest() == manifest["source_layout_sha256"]
    for asset in manifest["assets"].values():
        path = KIT / "portable" / asset["file"]
        assert hashlib.sha256(path.read_bytes()).hexdigest() == asset["sha256"], path
        if asset.get("atlas"):
            entry = asset["atlas"]
            x, y, width, height = entry["rect"]
            atlas = Image.open(KIT / "portable" / entry["file"]).convert("RGBA")
            original = Image.open(path).convert("RGBA")
            assert atlas.crop((x, y, x + width, y + height)).tobytes() == original.tobytes(), path
    screenshots = report / "chromium"
    screenshots.mkdir(exist_ok=True)
    results = {"native": [], "mobile": [], "interaction": [], "browser_errors": []}
    with server() as base_url, sync_playwright() as playwright:
        browser = playwright.chromium.launch(executable_path=chromium, headless=True,
                                             args=["--no-sandbox", "--force-color-profile=srgb"])
        page = browser.new_page(device_scale_factor=1)
        page.on("pageerror", lambda error: results["browser_errors"].append(str(error)))
        for screen in manifest["screens"]:
            width, height = screen["size"]
            page.set_viewport_size({"width": width, "height": height})
            page.goto(f"{base_url}?render=1&screen={screen['id']}")
            page.evaluate("window.uiReady")
            assert page.locator(".source-reference").count() == 0
            sources = page.locator("#stage img").evaluate_all("items => items.map(item => item.src)")
            assert all("/reference/" not in source for source in sources)
            assert len(sources) > 1
            data = page.screenshot()
            (screenshots / (screen["id"] + ".png")).write_bytes(data)
            actual = Image.open(BytesIO(data)).convert("RGB")
            original = source_image(screen)
            delta = np.abs(np.asarray(actual).astype(np.int16) - np.asarray(original).astype(np.int16))
            changed = (delta.max(axis=2) > 0)
            result = {"screen": screen["id"], "changed_pixels": int(changed.sum()),
                      "mean_channel_delta": float(delta.mean()), "max_channel_delta": int(delta.max()),
                      "pixel_match_percent": float((1 - changed.mean()) * 100)}
            results["native"].append(result)
            print(screen["id"], result["pixel_match_percent"], flush=True)
            assert result["changed_pixels"] == 0, result
        for width, height, safe in [(844, 390, "24,0,24,12"), (1024, 768, "12,16,12,16"), (1280, 720, "0,0,0,0")]:
            for ident in ["start_passport", "track_select_more", "car_select", "settings", "tuning_effects", "race_hud", "tour_hud", "result_tour"]:
                page.set_viewport_size({"width": width, "height": height})
                page.goto(f"{base_url}?render=1&screen={ident}&safe={safe}&language=ko")
                page.evaluate("window.uiReady")
                page.evaluate("document.fonts.ready")
                bounds = page.locator("#stage").bounding_box()
                assert bounds["x"] >= 0 and bounds["y"] >= 0
                assert bounds["x"] + bounds["width"] <= width + .01
                assert bounds["y"] + bounds["height"] <= height + .01
                minimum = page.locator("#stage button.part").evaluate_all("""items => items.map(node => {
                  const style = getComputedStyle(node, '::after');
                  const scale = window.uiKit.state().scale;
                  return {id: node.dataset.layer, width: parseFloat(style.width) * scale,
                          height: parseFloat(style.height) * scale};
                })""")
                assert all(item["width"] >= 43.9 and item["height"] >= 43.9 for item in minimum), minimum
                results["mobile"].append({"screen": ident, "viewport": [width, height], "safe": safe,
                                          "targets": len(minimum), "stage": bounds})
                if ident in ("settings", "tour_hud", "tuning_effects"):
                    page.screenshot(path=str(screenshots / f"{ident}_{width}x{height}_ko.png"))
        page.set_viewport_size({"width": 1280, "height": 720})
        page.goto(f"{base_url}?render=1&screen=start_passport")
        page.evaluate("window.uiReady")
        page.locator('[data-layer="settings"]').click()
        assert page.evaluate("window.uiKit.state().screen") == "settings"
        results["interaction"].append("설정 진입")
        slider = page.locator('[data-layer="sound_volume"] input')
        slider.focus()
        slider.press("Home")
        slider.press("ArrowRight")
        assert page.locator('[data-layer="sound_volume"]').get_attribute("data-value") == "1"
        results["interaction"].append("효과음 슬라이더 입력·시각 갱신")
        page.locator('[data-layer="controls"]').click()
        assert page.evaluate("window.uiKit.state().screen") == "controls_settings"
        page.locator('[data-layer="back"]').click()
        assert page.evaluate("window.uiKit.state().screen") == "settings"
        results["interaction"].append("조작 설정·한 단계 뒤로가기")
        page.evaluate("window.uiKit.navigate('tuning_shop')")
        page.evaluate("window.uiReady")
        page.locator('[data-layer="tab_effects"]').click()
        assert page.evaluate("window.uiKit.state().screen") == "tuning_effects"
        results["interaction"].append("튜닝 탭 전환")
        page.goto(f"{base_url}?screen=race_hud&background=checker")
        page.evaluate("window.uiReady")
        assert page.locator("#stage > .scene-background").count() == 0
        page.screenshot(path=str(screenshots / "race_hud_transparent.png"))
        results["interaction"].append("월드 배경 없이 HUD 부품만 렌더")
        page.goto(f"{base_url}?screen=controls_settings&language=en")
        page.evaluate("window.uiReady")
        page.evaluate("document.fonts.ready")
        page.screenshot(path=str(screenshots / "controls_long_english.png"))
        page.goto(f"{base_url}?screen=tuning_shop&background=clean&language=ko")
        page.evaluate("window.uiReady")
        page.screenshot(path=str(screenshots / "tuning_clean_background.png"))
        browser.close()
    (report / "results.json").write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    assert not results["browser_errors"], results["browser_errors"]
    print(f"Chromium: {len(results['native'])}개 원화 비교, {len(results['mobile'])}개 모바일 조합, 입력 PASS")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path, default=ROOT / "build/reports/rev3-ui-kit")
    parser.add_argument("--chromium", default="/usr/bin/chromium")
    arguments = parser.parse_args()
    validate(arguments.report, arguments.chromium)
