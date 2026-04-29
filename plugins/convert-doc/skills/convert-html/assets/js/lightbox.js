/**
 * ライトボックス
 * - 画像: 初期表示をビューポートに最大フィット。CSS transformでズーム/パン
 * - SVG (mermaid図・SVG画像): 初期表示をビューポートに最大フィット。
 *   viewBox操作でズーム/パンすることでベクター品質を維持する
 *
 * ズーム操作: スクロール ／ パン: ドラッグ ／ リセット: ダブルクリック
 */
(function () {
    'use strict';

    /* ===== DOM構築 ===== */
    var overlay = document.createElement('div');
    overlay.id = 'lb-overlay';
    var box = document.createElement('div');
    box.id = 'lb-box';
    var closeBtn = document.createElement('button');
    closeBtn.id = 'lb-close';
    closeBtn.innerHTML = '&times;';
    closeBtn.title = '閉じる (Esc)';
    var hint = document.createElement('div');
    hint.id = 'lb-hint';
    hint.textContent = 'スクロール: ズーム ／ ドラッグ: 移動 ／ ダブルクリック: リセット';
    overlay.appendChild(closeBtn);
    overlay.appendChild(box);
    overlay.appendChild(hint);
    document.body.appendChild(overlay);

    /* ===== ラスター画像の状態 ===== */
    var scale = 1, tx = 0, ty = 0;

    /* ===== SVGの状態 ===== */
    var currentSvg = null;
    var svgOrigViewBox = null; // {x, y, w, h}
    var svgZoom = 1;
    var svgPanX = 0, svgPanY = 0; // SVG座標系でのパン量

    /* ===== ドラッグ共通状態 ===== */
    var dragging = false, ox = 0, oy = 0;

    /* ===== ビューポートへの最大フィットサイズ計算 ===== */
    /**
     * コンテンツを90vw×90vh内に最大フィットさせるCSSサイズを返す。
     * 縦横どちらかが90vw/90vhに接するまで拡大縮小する。
     * @param {number} contentW コンテンツの幅
     * @param {number} contentH コンテンツの高さ
     * @returns {{w: number, h: number}}
     */
    function calcFitSize(contentW, contentH) {
        var maxW = window.innerWidth * 0.9;
        var maxH = window.innerHeight * 0.9;
        var ratio = Math.min(maxW / contentW, maxH / contentH);
        return { w: Math.round(contentW * ratio), h: Math.round(contentH * ratio) };
    }

    /* ===== ラスター画像のトランスフォーム適用 ===== */
    function applyTransform() {
        box.style.transform = 'translate(' + tx + 'px,' + ty + 'px) scale(' + scale + ')';
    }

    /* ===== SVGのビューボックス適用 ===== */
    /**
     * svgZoom・svgPanX・svgPanYを元にSVGのviewBoxを更新する。
     * ベクターSVGはviewBox変更により再レンダリングされるため画質が保持される。
     */
    function applySvgViewBox() {
        if (!currentSvg || !svgOrigViewBox) return;
        var vw = svgOrigViewBox.w / svgZoom;
        var vh = svgOrigViewBox.h / svgZoom;
        var vx = svgOrigViewBox.x + (svgOrigViewBox.w - vw) / 2 + svgPanX;
        var vy = svgOrigViewBox.y + (svgOrigViewBox.h - vh) / 2 + svgPanY;
        currentSvg.setAttribute('viewBox', vx + ' ' + vy + ' ' + vw + ' ' + vh);
    }

    /* ===== SVGの初期viewBox情報を取得 ===== */
    function extractViewBox(svgEl) {
        var attr = svgEl.getAttribute('viewBox');
        if (attr) {
            var parts = attr.trim().split(/[\s,]+/).map(parseFloat);
            if (parts.length === 4 && !parts.some(isNaN)) {
                return { x: parts[0], y: parts[1], w: parts[2], h: parts[3] };
            }
        }
        /* viewBoxがない場合はwidth/height属性から推定 */
        var w = parseFloat(svgEl.getAttribute('width')) || 800;
        var h = parseFloat(svgEl.getAttribute('height')) || 600;
        svgEl.setAttribute('viewBox', '0 0 ' + w + ' ' + h);
        return { x: 0, y: 0, w: w, h: h };
    }

    /* ===== ラスター画像を開く ===== */
    function openImg(src) {
        box.innerHTML = '';
        scale = 1; tx = 0; ty = 0;
        currentSvg = null; svgOrigViewBox = null;

        var img = document.createElement('img');
        img.style.cssText = 'display:block;';
        img.onload = function () {
            var size = calcFitSize(img.naturalWidth || 400, img.naturalHeight || 300);
            img.style.width = size.w + 'px';
            img.style.height = size.h + 'px';
        };
        img.src = src;
        box.appendChild(img);
        applyTransform();
        overlay.style.display = 'flex';
        document.body.style.overflow = 'hidden';
    }

    /* ===== SVG要素を開く（ベクターズーム） ===== */
    /**
     * SVG要素をインラインクローンとしてライトボックスに表示する。
     * ズームはviewBox操作で行うため、どのズームレベルでも文字・線がクリアに表示される。
     * @param {SVGElement} svgEl
     */
    function openSvgEl(svgEl) {
        box.innerHTML = '';
        scale = 1; tx = 0; ty = 0;
        applyTransform();

        var clone = svgEl.cloneNode(true);
        clone.removeAttribute('style');

        svgOrigViewBox = extractViewBox(clone);
        svgZoom = 1;
        svgPanX = 0; svgPanY = 0;

        var size = calcFitSize(svgOrigViewBox.w, svgOrigViewBox.h);
        clone.setAttribute('width', size.w);
        clone.setAttribute('height', size.h);
        clone.style.cssText = 'display:block;';

        currentSvg = clone;
        box.appendChild(currentSvg);
        overlay.style.display = 'flex';
        document.body.style.overflow = 'hidden';
    }

    /* ===== SVGデータURIをデコードして開く ===== */
    function openSvgFromDataUri(src) {
        try {
            var svgStr;
            var b64prefix = 'data:image/svg+xml;base64,';
            var rawPrefix = 'data:image/svg+xml,';
            if (src.startsWith(b64prefix)) {
                svgStr = atob(src.slice(b64prefix.length));
            } else if (src.startsWith(rawPrefix)) {
                svgStr = decodeURIComponent(src.slice(rawPrefix.length));
            } else {
                openImg(src);
                return;
            }
            var parser = new DOMParser();
            var doc = parser.parseFromString(svgStr, 'image/svg+xml');
            var svgEl = doc.documentElement;
            if (svgEl && svgEl.tagName === 'svg') {
                openSvgEl(svgEl);
            } else {
                openImg(src);
            }
        } catch (e) {
            openImg(src);
        }
    }

    /* ===== 閉じる ===== */
    function close() {
        overlay.style.display = 'none';
        document.body.style.overflow = '';
        currentSvg = null;
        svgOrigViewBox = null;
        svgZoom = 1; svgPanX = 0; svgPanY = 0;
        scale = 1; tx = 0; ty = 0;
    }

    /* ===== ズーム (ホイール) ===== */
    box.addEventListener('wheel', function (e) {
        e.preventDefault();
        var factor = e.deltaY < 0 ? 1.15 : 0.87;
        if (currentSvg && svgOrigViewBox) {
            /* SVG: viewBoxを縮小/拡大してベクター品質を維持 */
            svgZoom = Math.min(20, Math.max(0.2, svgZoom * factor));
            applySvgViewBox();
        } else {
            /* ラスター: CSS transform */
            scale = Math.min(10, Math.max(0.2, scale * factor));
            applyTransform();
        }
    }, { passive: false });

    /* ===== ドラッグ (パン) ===== */
    box.addEventListener('mousedown', function (e) {
        if (e.button !== 0) return;
        dragging = true;
        if (currentSvg && svgOrigViewBox) {
            /* SVG: 前回座標を記録（差分でSVG座標変換） */
            ox = e.clientX;
            oy = e.clientY;
        } else {
            ox = e.clientX - tx;
            oy = e.clientY - ty;
        }
        box.style.cursor = 'grabbing';
        e.preventDefault();
    });

    document.addEventListener('mousemove', function (e) {
        if (!dragging) return;
        if (currentSvg && svgOrigViewBox) {
            var dx = e.clientX - ox;
            var dy = e.clientY - oy;
            ox = e.clientX;
            oy = e.clientY;
            /* スクリーン座標をSVG座標へ変換してviewBoxを移動 */
            var rect = currentSvg.getBoundingClientRect();
            var vw = svgOrigViewBox.w / svgZoom;
            var vh = svgOrigViewBox.h / svgZoom;
            if (rect.width > 0 && rect.height > 0) {
                svgPanX -= dx * (vw / rect.width);
                svgPanY -= dy * (vh / rect.height);
            }
            applySvgViewBox();
        } else {
            tx = e.clientX - ox;
            ty = e.clientY - oy;
            applyTransform();
        }
    });

    document.addEventListener('mouseup', function () {
        dragging = false;
        box.style.cursor = 'grab';
    });

    /* ===== ダブルクリックでリセット ===== */
    box.addEventListener('dblclick', function () {
        if (currentSvg && svgOrigViewBox) {
            svgZoom = 1; svgPanX = 0; svgPanY = 0;
            applySvgViewBox();
        } else {
            scale = 1; tx = 0; ty = 0;
            applyTransform();
        }
    });

    /* ===== 閉じるイベント ===== */
    overlay.addEventListener('click', function (e) { if (e.target === overlay) close(); });
    closeBtn.addEventListener('click', close);
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape') close(); });

    /* ===== ターゲット登録 ===== */
    function register() {
        /* 通常画像: SVGデータURIはデコードしてベクター表示 */
        document.querySelectorAll('.article-body img').forEach(function (img) {
            img.style.cursor = 'zoom-in';
            img.addEventListener('click', function (e) {
                e.stopPropagation();
                var src = img.src;
                if (src.startsWith('data:image/svg+xml') || /\.svg(\?|$)/i.test(src)) {
                    openSvgFromDataUri(src);
                } else {
                    openImg(src);
                }
            });
        });
        /* Mermaid図 (.mermaid-figure 内のSVG): viewBoxズームで品質保持 */
        /* クリック範囲をSVG要素自体に限定し、周囲の余白では反応しないようにする */
        document.querySelectorAll('.mermaid-figure svg').forEach(function (svg) {
            svg.style.cursor = 'zoom-in';
            svg.title = 'クリックで拡大';
            svg.addEventListener('click', function () { openSvgEl(svg); });
        });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', register);
    } else {
        register();
    }
}());
