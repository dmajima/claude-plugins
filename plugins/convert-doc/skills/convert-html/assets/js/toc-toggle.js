/**
 * 目次
 * - デスクトップ（>1024px）: 画面右端の縦長トグルボタン（▶/◀）でサイドバー目次を表示/非表示
 * - モバイル（≤1024px）  : ヘッダーのハンバーガーボタンでドロワー形式の目次を表示/非表示
 * このスクリプトが有効（features.json に含まれる）場合のみ目次がHTMLに出力される
 */
(function () {
    'use strict';

    const STORAGE_KEY = 'toc-collapsed';
    const COLLAPSED_CLASS = 'toc-collapsed';
    const MOBILE_OPEN_CLASS = 'toc-mobile-open';
    const MOBILE_BREAKPOINT = 1024;

    let desktopToggleBtn = null;
    let mobileHeader = null;
    let mobileOverlay = null;
    let escHandler = null;
    let tocLinkHandler = null;

    // ---------- DOM ユーティリティ ----------

    /**
     * 要素をDOMから削除する
     * @param {HTMLElement|null} el
     */
    function removeEl(el) {
        if (el && el.parentNode) {
            el.parentNode.removeChild(el);
        }
    }

    // ---------- デスクトップ ----------

    /**
     * デスクトップ用トグルボタンを生成してbodyに追加する
     * @returns {HTMLElement}
     */
    function createDesktopToggleBtn() {
        const btn = document.createElement('div');
        btn.id = 'toc-toggle-btn';
        btn.setAttribute('role', 'button');
        btn.setAttribute('aria-label', '目次の表示/非表示');
        btn.setAttribute('tabindex', '0');
        document.body.appendChild(btn);
        return btn;
    }

    /**
     * デスクトップトグルボタンのアイコンを更新する
     * @param {HTMLElement} btn
     * @param {boolean} collapsed
     */
    function updateDesktopIcon(btn, collapsed) {
        btn.textContent = collapsed ? '◀' : '▶';
        btn.setAttribute('aria-expanded', collapsed ? 'false' : 'true');
    }

    /**
     * デスクトップの目次表示/非表示を切り替える
     * @param {HTMLElement} sidebar
     * @param {HTMLElement} btn
     */
    function toggleDesktop(sidebar, btn) {
        const collapsed = sidebar.classList.toggle(COLLAPSED_CLASS);
        updateDesktopIcon(btn, collapsed);
        try {
            sessionStorage.setItem(STORAGE_KEY, collapsed ? '1' : '0');
        } catch (e) {}
    }

    /**
     * デスクトップモードをセットアップする
     * @param {HTMLElement} sidebar
     */
    function setupDesktop(sidebar) {
        teardownMobile(sidebar);
        sidebar.classList.remove(MOBILE_OPEN_CLASS);

        desktopToggleBtn = createDesktopToggleBtn();

        let initialCollapsed = false;
        try {
            initialCollapsed = sessionStorage.getItem(STORAGE_KEY) === '1';
        } catch (e) {}

        if (initialCollapsed) {
            sidebar.classList.add(COLLAPSED_CLASS);
        }
        updateDesktopIcon(desktopToggleBtn, initialCollapsed);

        desktopToggleBtn.addEventListener('click', function () {
            toggleDesktop(sidebar, desktopToggleBtn);
        });
        desktopToggleBtn.addEventListener('keydown', function (e) {
            if (e.key === 'Enter' || e.key === ' ') {
                e.preventDefault();
                toggleDesktop(sidebar, desktopToggleBtn);
            }
        });
    }

    /**
     * デスクトップモードを解体する
     * @param {HTMLElement} sidebar
     */
    function teardownDesktop(sidebar) {
        removeEl(desktopToggleBtn);
        desktopToggleBtn = null;
        sidebar.classList.remove(COLLAPSED_CLASS);
    }

    // ---------- モバイル ----------

    /**
     * モバイルヘッダーを生成してbodyの先頭に追加する
     * @param {HTMLElement} sidebar
     * @returns {HTMLElement}
     */
    function createMobileHeader(sidebar) {
        const header = document.createElement('header');
        header.id = 'toc-mobile-header';

        const hamburgerBtn = document.createElement('button');
        hamburgerBtn.id = 'toc-hamburger-btn';
        hamburgerBtn.setAttribute('aria-label', '目次を開く');
        hamburgerBtn.setAttribute('aria-expanded', 'false');
        hamburgerBtn.setAttribute('aria-controls', 'toc-sidebar');
        hamburgerBtn.innerHTML = '&#9776;'; // ☰

        const titleSpan = document.createElement('span');
        titleSpan.id = 'toc-mobile-header-title';
        titleSpan.textContent = document.title || '目次';

        header.appendChild(titleSpan);
        header.appendChild(hamburgerBtn);
        document.body.insertBefore(header, document.body.firstChild);

        hamburgerBtn.addEventListener('click', function () {
            openMobileToc(sidebar, hamburgerBtn);
        });

        return header;
    }

    /**
     * モバイルオーバーレイ背景を生成してbodyに追加する
     * @param {HTMLElement} sidebar
     * @returns {HTMLElement}
     */
    function createMobileOverlay(sidebar) {
        const overlay = document.createElement('div');
        overlay.id = 'toc-mobile-overlay';
        document.body.appendChild(overlay);
        overlay.addEventListener('click', function () {
            closeMobileToc(sidebar);
        });
        return overlay;
    }

    /**
     * モバイルドロワーを開く
     * @param {HTMLElement} sidebar
     * @param {HTMLElement} btn
     */
    function openMobileToc(sidebar, btn) {
        sidebar.classList.add(MOBILE_OPEN_CLASS);
        if (mobileOverlay) mobileOverlay.classList.add('active');
        btn.setAttribute('aria-expanded', 'true');
        btn.setAttribute('aria-label', '目次を閉じる');
        document.body.style.overflow = 'hidden';
    }

    /**
     * モバイルドロワーを閉じる
     * @param {HTMLElement} sidebar
     */
    function closeMobileToc(sidebar) {
        sidebar.classList.remove(MOBILE_OPEN_CLASS);
        if (mobileOverlay) mobileOverlay.classList.remove('active');
        const btn = document.getElementById('toc-hamburger-btn');
        if (btn) {
            btn.setAttribute('aria-expanded', 'false');
            btn.setAttribute('aria-label', '目次を開く');
        }
        document.body.style.overflow = '';
    }

    /**
     * モバイルモードをセットアップする
     * @param {HTMLElement} sidebar
     */
    function setupMobile(sidebar) {
        teardownDesktop(sidebar);
        mobileHeader = createMobileHeader(sidebar);
        mobileOverlay = createMobileOverlay(sidebar);

        escHandler = function (e) {
            if (e.key === 'Escape') {
                closeMobileToc(sidebar);
            }
        };
        document.addEventListener('keydown', escHandler);

        // 目次リンクをタップしたらドロワーを閉じる（ヘッダーで遷移先が隠れないようにするため）
        tocLinkHandler = function (e) {
            const anchor = e.target.closest('a');
            if (anchor) {
                closeMobileToc(sidebar);
            }
        };
        sidebar.addEventListener('click', tocLinkHandler);
    }

    /**
     * モバイルモードを解体する
     * @param {HTMLElement} sidebar
     */
    function teardownMobile(sidebar) {
        removeEl(mobileHeader);
        removeEl(mobileOverlay);
        mobileHeader = null;
        mobileOverlay = null;
        sidebar.classList.remove(MOBILE_OPEN_CLASS);
        document.body.style.overflow = '';
        if (escHandler) {
            document.removeEventListener('keydown', escHandler);
            escHandler = null;
        }
        if (tocLinkHandler) {
            sidebar.removeEventListener('click', tocLinkHandler);
            tocLinkHandler = null;
        }
    }

    // ---------- 初期化 ----------

    function init() {
        const sidebar = document.getElementById('toc-sidebar');
        if (!sidebar) return;

        const mq = window.matchMedia('(max-width: ' + MOBILE_BREAKPOINT + 'px)');

        function setup(isMobile) {
            if (isMobile) {
                setupMobile(sidebar);
            } else {
                setupDesktop(sidebar);
            }
        }

        setup(mq.matches);

        mq.addEventListener('change', function (e) {
            setup(e.matches);
        });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
}());
