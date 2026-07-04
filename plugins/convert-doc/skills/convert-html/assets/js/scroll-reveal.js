/**
 * スクロールリビール
 * - スクロールに応じてセクション（.content-section .section-inner）を
 *   ふわっとフェードイン表示する演出（IntersectionObserver）
 * - プログレッシブエンハンスメント方式:
 *   本スクリプトが <html> に sr-ready クラスを付与した場合のみ、CSS 側
 *   （executive.css）で初期非表示になる。JS 無効環境・非対応環境では
 *   クラスが付与されず、全要素が最初から表示される
 * - prefers-reduced-motion: reduce の環境では演出を行わない
 * - 対象要素が存在しないテンプレート（ドキュメント型等）では何もしない
 */
(function () {
    'use strict';

    function init() {
        var targets = document.querySelectorAll('.content-section .section-inner');
        if (!targets.length) return;
        if (!('IntersectionObserver' in window)) return;
        if (window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

        document.documentElement.classList.add('sr-ready');

        var observer = new IntersectionObserver(function (entries) {
            entries.forEach(function (entry) {
                if (entry.isIntersecting) {
                    entry.target.classList.add('sr-in');
                    observer.unobserve(entry.target);
                }
            });
        }, { rootMargin: '0px 0px -8% 0px', threshold: 0.05 });

        targets.forEach(function (el) {
            var rect = el.getBoundingClientRect();
            /* 初期表示時点でビューポート内にある要素はフェードインのみ（監視不要） */
            if (rect.top < window.innerHeight * 0.92) {
                el.classList.add('sr-in');
            } else {
                observer.observe(el);
            }
        });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
}());
