/* 원화·PNG·실제 입력이 같은 좌표 목록을 사용합니다. 게임 로직은 포함하지 않습니다. */
(() => {
  "use strict";
  const kit = window.REV3_UI_KIT;
  const query = new URLSearchParams(location.search);
  const byId = new Map(kit.screens.map(screen => [screen.id, screen]));
  const stage = document.querySelector("#stage");
  const viewport = document.querySelector("#viewport");
  const screenSelect = document.querySelector("#screen");
  const hidden = new Set();
  const layerElements = new Map();
  let current = byId.get(query.get("screen")) || byId.get("start_passport");
  let lastAction = "";
  let scale = 1;
  const renderOnly = query.get("render") === "1";
  const history = [];
  const actionLabels = {
    back: ["뒤로", "Back"], settings: ["설정", "Settings"], tour: ["투어", "Grand Tour"],
    track: ["트랙", "Track Racing"], passport: ["투어 패스포트", "Tour Passport"],
    continue: ["차량 선택", "Choose Your Car"], start_race: ["출발", "Start Racing"],
    tuning: ["튜닝샵", "Vehicle Customization"], cancel: ["취소", "Cancel Changes"],
    apply: ["적용", "Apply Changes"], reset: ["초기화", "Reset to Default"],
    done: ["완료", "Save Settings"], controls: ["조작 설정", "Touch Control Layout"],
    resume: ["계속 주행", "Resume Racing"], retry: ["재시도", "Try Again"],
    home: ["선택 화면", "Return to Selection"], color_cancel: ["취소", "Cancel"],
    color_done: ["색상 확인", "Confirm Color"], keep_editing: ["계속 편집", "Keep Editing"],
    discard_changes: ["변경 폐기", "Discard Unsaved Changes"], route_left: ["정글 캐노피", "Lush Jungle Canopy"],
    route_right: ["스카이라인 드라이브", "Downtown Skyline Drive"],
    steering_left: ["왼손 조향", "Left-hand Steering"], steering_right: ["오른손 조향", "Right-hand Steering"],
    motion: ["동작\n감소", "Reduce\nmotion"], fps: ["FPS", "FPS"],
    tab_paint: ["도장", "Body Paint"], tab_livery: ["리버리", "Custom Livery"],
    tab_wheels: ["휠", "Wheel Design"], tab_wing: ["리어윙", "Rear Wing"],
    tab_shading: ["셰이딩", "Shading Style"], tab_effects: ["이펙트", "Effect Equipment"],
  };
  for (const screen of kit.screens) {
    const option = new Option(screen.title, screen.id);
    screenSelect.add(option);
  }
  if (renderOnly) document.body.classList.add("render-only");
  if (query.has("language")) document.querySelector("#language").value = query.get("language");
  if (query.has("background")) document.querySelector("#background").value = query.get("background");

  function flatten(layers) {
    return layers.flatMap(layer => [layer, ...flatten(layer.children || [])]);
  }

  function image(path, className) {
    const node = document.createElement("img");
    node.src = path;
    node.className = className;
    node.draggable = false;
    node.alt = "";
    return node;
  }

  function fit() {
    const [width, height] = current.size;
    const presets = { phone: [844, 390], fold: [1024, 768], wide: [1280, 720], native: [width, height] };
    let available = presets[document.querySelector("#device").value];
    if (renderOnly) available = [innerWidth, innerHeight];
    const maxWidth = renderOnly ? innerWidth : document.querySelector(".viewer").clientWidth;
    const factor = Math.min(1, maxWidth / available[0]);
    viewport.style.width = `${available[0] * factor}px`;
    viewport.style.height = `${available[1] * factor}px`;
    const safe = (query.get("safe") || "0,0,0,0").split(",").map(Number);
    const [left, top, right, bottom] = safe;
    const availableWidth = available[0] - left - right;
    const availableHeight = available[1] - top - bottom;
    scale = Math.min(availableWidth / width, availableHeight / height) * factor;
    stage.style.width = `${width}px`;
    stage.style.height = `${height}px`;
    stage.style.transform = `scale(${scale})`;
    stage.style.setProperty("--minimum-target", `${44 / scale}px`);
    stage.style.left = `${left * factor + (availableWidth * factor - width * scale) / 2}px`;
    stage.style.top = `${top * factor + (availableHeight * factor - height * scale) / 2}px`;
    document.querySelector("#status").textContent = `${current.title} · ${width} × ${height} · 배율 ${scale.toFixed(3)} · ${flatten(current.layers).length}개 부품`;
  }

  function labelFor(layer) {
    const language = document.querySelector("#language").value;
    if (language === "none" || !layer.action || layer.rect[2] < 340 || layer.rect[2] < layer.rect[3] * 1.8) return "";
    const pair = actionLabels[layer.id];
    return pair ? pair[language === "ko" ? 0 : 1] : (language === "ko" ? layer.label || "선택" : "Select This Option");
  }

  function activate(layer) {
    lastAction = layer.action;
    document.querySelector("#interaction").value = `입력 확인: ${layer.id} → ${layer.action}`;
    if (layer.action === "back") {
      navigate(history.pop() || "start_passport", false);
    } else if (byId.has(layer.action)) {
      navigate(layer.action);
    } else if (layer.id.endsWith("_toggle")) {
      const node = layerElements.get(layer.id);
      node.classList.toggle("interacting");
      node.dataset.enabled = node.dataset.enabled === "false" ? "true" : "false";
    } else {
      layerElements.get(layer.id)?.classList.toggle("interacting");
    }
  }

  function renderLayer(layer, parent, parentOrigin, namespace = "") {
    const [x, y, width, height] = layer.rect;
    if (layer.kind === "screen_instance") {
      const instance = document.createElement("div");
      instance.className = "part";
      Object.assign(instance.style, { left: `${x}px`, top: `${y}px`, width: `${width}px`, height: `${height}px` });
      parent.append(instance);
      renderScreen(byId.get(layer.screen), instance, `${layer.screen}/`);
      return;
    }
    const node = document.createElement(layer.action ? "button" : "div");
    node.className = "part";
    if (layer.action) {
      node.type = "button";
      node.setAttribute("aria-label", layer.label || layer.id);
      node.addEventListener("click", event => { event.stopPropagation(); activate(layer); });
    }
    node.dataset.layer = namespace + layer.id;
    node.dataset.kind = layer.kind;
    Object.assign(node.style, { left: `${x - parentOrigin[0]}px`, top: `${y - parentOrigin[1]}px`, width: `${width}px`, height: `${height}px` });
    const asset = kit.assets[layer.asset];
    if (asset.atlas) {
      const sprite = document.createElement("div");
      sprite.className = "asset atlas-sprite";
      sprite.style.backgroundImage = `url(portable/${asset.atlas.file})`;
      sprite.style.backgroundPosition = `-${asset.atlas.rect[0]}px -${asset.atlas.rect[1]}px`;
      sprite.dataset.atlas = asset.atlas.file;
      node.append(sprite);
    } else {
      node.append(image(`portable/${asset.file}`, "asset"));
    }
    for (const child of layer.children) renderLayer(child, node, [x, y], namespace);
    const text = labelFor(layer);
    if (text) {
      const label = document.createElement("span");
      label.className = "part-label";
      label.textContent = text;
      label.style.fontSize = `${Math.min(34, Math.max(17, height * .26))}px`;
      if (layer.kind === "card" || layer.children.some(child => child.kind === "illustration")) label.style.left = "46%";
      if (layer.label_rect) {
        const [labelX, labelY, labelWidth, labelHeight] = layer.label_rect;
        Object.assign(label.style, { left: `${labelX - x}px`, top: `${labelY - y}px`, width: `${labelWidth}px`, height: `${labelHeight}px`, right: "auto" });
      }
      node.append(label);
    }
    if (["slider", "progress"].includes(layer.kind)) {
      const range = document.createElement("input");
      range.type = "range";
      range.min = "0";
      range.max = "100";
      range.value = String(Math.round((layer.value || .5) * 100));
      range.className = "slider-input";
      range.setAttribute("aria-label", layer.id);
      range.addEventListener("input", () => {
        let track = node.querySelector(".live-slider");
        if (!track) {
          for (const child of [...node.children]) if (child !== range) child.remove();
          track = document.createElement("div");
          track.className = "live-slider";
          track.append(document.createElement("i"), document.createElement("b"));
          node.prepend(track);
        }
        const fill = track.querySelector("i");
        fill.style.width = `${range.value}%`;
        const knob = track.querySelector("b");
        knob.style.left = `${range.value}%`;
        node.dataset.value = range.value;
        const titleId = layer.id === "sound_volume" ? "sound_title" : layer.id === "music_volume" ? "music_title" : "";
        const title = titleId ? stage.querySelector(`[data-slot="${titleId}"]`) : null;
        if (title) {
          const korean = document.querySelector("#language").value === "ko";
          const prefix = titleId === "sound_title" ? (korean ? "효과음" : "Sound effects") : (korean ? "배경음악" : "Background music");
          title.textContent = `${prefix} · ${range.value}%`;
        }
        lastAction = layer.id;
        document.querySelector("#interaction").value = `${layer.id}: ${range.value} / 100`;
      });
      node.append(range);
    }
    layerElements.set(namespace + layer.id, node);
    if (!namespace) layerElements.set(layer.id, node);
    if (hidden.has(namespace + layer.id)) node.hidden = true;
    parent.append(node);
  }

  function renderScreen(screen, parent, namespace = "") {
    const backgroundMode = document.querySelector("#background").value;
    if (backgroundMode !== "checker") {
      const path = backgroundMode === "alternate" ? "inputs/clean_menu.png"
        : backgroundMode === "clean" ? `portable/${screen.background.clean_plate}` : `portable/${screen.background.file}`;
      parent.append(image(path, "scene-background"));
    }
    for (const layer of screen.layers) renderLayer(layer, parent, [0, 0], namespace);
    const language = document.querySelector("#language").value;
    if (language !== "none") {
      for (const slot of screen.text_slots || []) {
        const node = document.createElement("div");
        node.className = "text-slot";
        node.dataset.slot = slot.id;
        node.textContent = slot[language];
        const [x, y, width, height] = slot.rect;
        Object.assign(node.style, { left: `${x}px`, top: `${y}px`, width: `${width}px`, height: `${height}px`, fontSize: `${slot.font_size || 40}px` });
        parent.append(node);
      }
    }
  }

  function render() {
    stage.replaceChildren();
    layerElements.clear();
    stage.classList.toggle("checker", document.querySelector("#background").value === "checker");
    stage.classList.toggle("outlines", document.querySelector("#outlines").checked);
    renderScreen(current, stage);
    if (document.querySelector("#reference").checked && !current.source_crop) {
      stage.append(image(`../../reference/rev3/${current.reference}`, "source-reference"));
    }
    const layers = document.querySelector("#layers");
    layers.replaceChildren();
    for (const layer of flatten(current.layers)) {
      const row = document.createElement("label");
      row.className = "layer-row";
      const toggle = document.createElement("input");
      toggle.type = "checkbox";
      toggle.checked = !hidden.has(layer.id);
      toggle.addEventListener("change", () => {
        if (toggle.checked) hidden.delete(layer.id); else hidden.add(layer.id);
        const node = layerElements.get(layer.id);
        if (node) node.hidden = !toggle.checked;
      });
      row.append(toggle, document.createTextNode(layer.id));
      layers.append(row);
    }
    screenSelect.value = current.id;
    fit();
    const atlasPaths = [...new Set([...stage.querySelectorAll("[data-atlas]")].map(node => node.dataset.atlas))];
    window.uiReady = Promise.all([
      ...[...stage.querySelectorAll("img")].map(img => img.decode()),
      ...atlasPaths.map(path => image(`portable/${path}`, "").decode()),
    ]).then(async () => {
      await document.fonts.ready;
      for (const node of stage.querySelectorAll(".text-slot, .part-label")) {
        let size = parseFloat(getComputedStyle(node).fontSize);
        while (size > 18 && (node.scrollWidth > node.clientWidth || node.scrollHeight > node.clientHeight)) {
          size -= 1;
          node.style.fontSize = `${size}px`;
        }
      }
    });
  }

  function navigate(id, remember = true) {
    if (remember) history.push(current.id);
    current = byId.get(id) || current;
    hidden.clear();
    render();
  }

  async function comparePixels() {
    await window.uiReady;
    const [width, height] = current.size;
    const canvas = document.querySelector("#difference_canvas");
    canvas.width = width;
    canvas.height = height;
    const context = canvas.getContext("2d", { willReadFrequently: true });
    const source = image(`../../reference/rev3/${current.reference}`, "");
    await source.decode();
    const crop = current.source_crop || [0, 0, width, height];
    context.drawImage(source, ...crop, 0, 0, width, height);
    const reference = context.getImageData(0, 0, width, height);
    context.clearRect(0, 0, width, height);
    async function drawScreen(screen, offsetX = 0, offsetY = 0) {
      const bg = image(`portable/${screen.background.file}`, "");
      await bg.decode();
      context.drawImage(bg, offsetX, offsetY);
      async function draw(layer) {
        if (layer.kind === "screen_instance") {
          await drawScreen(byId.get(layer.screen), offsetX + layer.rect[0], offsetY + layer.rect[1]);
          return;
        }
        const part = image(`portable/${kit.assets[layer.asset].file}`, "");
        await part.decode();
        context.drawImage(part, offsetX + layer.rect[0], offsetY + layer.rect[1]);
        for (const child of layer.children) await draw(child);
      }
      for (const layer of screen.layers) await draw(layer);
    }
    await drawScreen(current);
    const assembled = context.getImageData(0, 0, width, height);
    let changed = 0;
    for (let i = 0; i < assembled.data.length; i += 4) {
      const delta = Math.max(...[0, 1, 2].map(channel => Math.abs(assembled.data[i + channel] - reference.data[i + channel])));
      if (delta) changed += 1;
      assembled.data[i] = delta ? 255 : 20;
      assembled.data[i + 1] = delta ? Math.max(0, 255 - delta * 8) : 35;
      assembled.data[i + 2] = delta ? 0 : 45;
      assembled.data[i + 3] = 255;
    }
    context.putImageData(assembled, 0, 0);
    canvas.hidden = false;
    document.querySelector("#status").textContent = `PNG 원화 대비 차이 ${changed.toLocaleString()} / ${(width * height).toLocaleString()} 픽셀`;
    return { changed, total: width * height };
  }

  screenSelect.addEventListener("change", () => navigate(screenSelect.value));
  for (const id of ["device", "language", "reference", "outlines", "background"]) {
    document.querySelector(`#${id}`).addEventListener("change", render);
  }
  document.querySelector("#reset").addEventListener("click", () => { hidden.clear(); render(); });
  document.querySelector("#difference").addEventListener("click", () => comparePixels().catch(error => {
    document.querySelector("#status").textContent = `픽셀 차이는 HTTP 서버에서 확인하세요: ${error.message}`;
  }));
  addEventListener("resize", fit);
  window.uiKit = { navigate, comparePixels, state: () => ({ screen: current.id, scale, lastAction, hidden: [...hidden] }) };
  render();
})();
