# Asset sources and licences

Everything the game ships, where it comes from and under which terms. Keep this file current
when an asset is added, replaced or removed. `tools/verify_repository.py` fails when a sound file
has no entry in `assets/audio/LICENSE.txt`. The game does not rely on any original arcade-game
asset, photograph or real manufacturer logo.

## Audio

| Files | Source | Licence |
| --- | --- | --- |
| `assets/audio/vehicles/<id>-engine.ogg`, `-boost.ogg`, `-boost-start.wav`, `-drift.ogg` (4 vehicles, 16 files) | Synthesized from scratch by `tools/bake_vehicle_audio.py` (numpy; no sample, recording or loop is read as input). `ffmpeg` only encodes the result to Ogg. | Owned by this project. No third-party terms. |
| `assets/audio/web-loops.json` | The same baked loops repackaged as base64 for the browser audio path (`tools/bake_vehicle_audio.py`). | Owned by this project. |
| `assets/audio/countdown.wav`, `launch.wav`, `reward.wav`, `lap.wav` | Short UI cues synthesized by `tools/bake_cues.py` (standard-library `wave`, `math`). | Owned by this project. |
| `assets/audio/impact.wav` | Derived from `impact_1.wav` of the **Truck Town** demo in the Godot demo projects (Godot Engine contributors, <https://github.com/godotengine/godot-demo-projects/tree/master/3d/truck_town/vehicles>). Filtered, resampled to mono, trimmed and faded out. | **MIT**. The licence text is `assets/audio/GODOT-LICENSE.txt`, shipped with the web export. |

This is the only third-party sound in the game. The OpenGameArt recordings that earlier builds used
for engine and tyre noise (CC BY 3.0, by qubodup and audible-edge) were replaced by the synthesized
sounds above and removed from the tree; they only remain in the Git history, so nothing under CC BY
needs crediting in a release.

There is no music. There are no voice lines.

The licence files `assets/audio/LICENSE.txt` and `GODOT-LICENSE.txt` are included in the web export
(`include_filter` in `export_presets.cfg`).

## Images and 3D

| Assets | Source | Licence |
| --- | --- | --- |
| Menu, garage and course artwork in `assets/ui/` (splash, home, garage, course cards, drift car, nitro bottle) | Generated for this project; see `assets/ui/GENERATED_ART.md`. | Generated art. Check the terms of the generator you used before a commercial release. |
| Road, dirt and grass textures, Fuji panorama, distant ridges (`assets/environment/*.png`) | Generated for this project; the rear sky panels are baked from the panorama by `tools/bake_fuji_backdrop.py`. See `assets/environment/README.md`. | Generated art, as above. |
| Fuji trackside trees, bushes and rocks (`assets/environment/props/`, 14 models) | Quaternius, *Ultimate Nature Pack*, <https://quaternius.com/packs/ultimatenature.html>. | **CC0 1.0** (public domain). Licence text in `QUATERNIUS-LICENSE.txt`. |
| Cars, roads, rails, tunnels, buildings, trucks, signs | Drawn in code (`scripts/*_body.gd`, `road_*.gd`, `road_features.gd`). | Owned by this project. |
| Game logo (`assets/ui/initialsj-logo.svg`) | Drawn for this project by `tools/bake_logo.py`. | Owned by this project (its lettering uses Roboto, below). |

## Fonts

| Files | Licence |
| --- | --- |
| `assets/fonts/Roboto-BoldItalic.ttf`, `Roboto-BlackItalic.ttf` (Google) | Apache License 2.0, `Roboto-LICENSE.txt` |
| `assets/fonts/LiberationSans-BoldItalic.ttf` | SIL Open Font License, `LICENSE.txt` |

## Engine

Godot Engine 4.7.2, MIT. Its licence text ships with the web export as well.

## Adding an asset

1. Use only CC0 / public-domain / MIT-style terms that allow commercial use and modification. Do not
   add anything that needs attribution unless it is listed here and in the credits.
2. Put the licence text next to the file and add a row here and to the folder's own README or LICENSE.
3. For sound, follow [VEHICLE_AUDIO.md](VEHICLE_AUDIO.md) and add the entry to `assets/audio/LICENSE.txt`.

## 생성형 광고 이미지 추가

`assets/environment/generated-racing-ads.png`는 2026-11-09 이미지 생성 도구로 제작한 원본 광고 아틀라스입니다. AEROVA·CANYON FIZZ·SUMMIT TIRE·ORBIT AUTO의 가상 광고 네 장을 2×2로 배치했습니다. 외부 사진이나 실존 브랜드 로고를 입력하지 않았으며 `scenic_landmarks.gd`의 `billboard_ad.gdshader`의 UV 영역으로 각 광고를 분리해 트랙5 간판에 사용합니다. 기존 벡터 광고와 별도 에셋입니다.

## 건물 전용 정면·측면 이미지

`building-front-elevations.png`, `building-side-elevations.png`, `restaurant-elevations.png`는 이미지 생성 도구로 제작한 건물별 외벽 원본입니다. 각 건물의 출입문·창틀·석재 기단·측면 창문·배관을 구분해 사용합니다. 원본 식별자와 배열은 `assets/environment/README.md`에 기록했습니다. 외부 사진이나 실존 브랜드 로고를 입력하지 않았습니다.

## 생성형 노면·지면 이미지

`assets/environment/asphalt-variants.png`와 `terrain-variants.png`는 2026-11-10 이미지 생성 도구로 제작한 아스팔트 4종과 잔디·흙·자갈 8종의 원본 아틀라스입니다. 외부 사진·게임 에셋·실존 브랜드를 입력하지 않았습니다. 배열·생성 원본 식별자·적용 방식은 `assets/environment/README.md`에 기록했습니다.
