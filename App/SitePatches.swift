import Foundation

/// 针对站点的渲染兼容补丁。
///
/// 背景：站点用 Tailwind v4 的 `bg-primary/[0.07]` 这类透明度类，编译产物是两条同选择器规则：
///   1) background-color: var(--primary)                                  ← 纯色兜底
///   2) background-color: color-mix(in oklab, var(--primary) 7%, transparent)  ← 正确值
///
/// `color-mix()` 需要 Safari 16.2+。当宿主（WKWebView）不支持时，第 2 条声明被整条丢弃，
/// 于是背景退化成 100% 不透明的主题绿，视觉上就是整张卡片变成一块亮绿色、内容被盖住。
///
/// 这里在运行时兜底：凡是「类名声明了透明度、但计算出来是不透明纯色」的元素，
/// 按类名里的 alpha 重新写回 rgba()。宿主本身支持 color-mix 时，计算值已经是半透明，
/// 会被自动跳过，不会重复干预。
enum SitePatches {

    static let alphaFallback = #"""
    (function () {
      if (window.__ghqAlphaPatch) { return; }
      window.__ghqAlphaPatch = true;

      // 匹配 bg-primary/[0.07] 或 bg-card/60 这类带透明度修饰的类名
      var RE = /(?:^|\s)bg-[a-zA-Z][\w-]*\/(?:\[(0?\.\d+)\]|(\d{1,3}))(?=\s|$)/;
      var pending = new Set();
      var frame = 0;

      function patch(el) {
        if (!el || el.nodeType !== 1 || !el.getAttribute) { return; }
        var cls = el.getAttribute('class');
        if (!cls || cls.indexOf('/') < 0) { return; }
        var m = RE.exec(cls);
        if (!m) { return; }

        var alpha = m[1] ? parseFloat(m[1]) : parseInt(m[2], 10) / 100;
        if (!(alpha > 0 && alpha < 1)) { return; }

        var parts = window.getComputedStyle(el).backgroundColor.match(/[\d.]+/g);
        if (!parts || parts.length < 3) { return; }
        // 已经是半透明 → 说明宿主解析正常，不动
        if (parts.length > 3 && parseFloat(parts[3]) < 0.999) { return; }

        el.style.backgroundColor =
          'rgba(' + parts[0] + ',' + parts[1] + ',' + parts[2] + ',' + alpha + ')';
      }

      function collect(node) {
        if (!node || node.nodeType !== 1) { return; }
        pending.add(node);
        if (node.querySelectorAll) {
          var kids = node.querySelectorAll('[class*="/"]');
          for (var i = 0; i < kids.length; i++) { pending.add(kids[i]); }
        }
      }

      function flush() {
        frame = 0;
        pending.forEach(patch);
        pending.clear();
      }

      function schedule() {
        if (!frame) { frame = window.requestAnimationFrame(flush); }
      }

      collect(document.documentElement);
      schedule();

      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', function () {
          collect(document.documentElement);
          schedule();
        });
      }

      try {
        new MutationObserver(function (records) {
          for (var i = 0; i < records.length; i++) {
            var r = records[i];
            if (r.type === 'attributes') {
              if (r.target) { pending.add(r.target); }
            } else {
              for (var j = 0; j < r.addedNodes.length; j++) {
                collect(r.addedNodes[j]);
              }
            }
          }
          schedule();
        }).observe(document.documentElement, {
          childList: true,
          subtree: true,
          attributes: true,
          attributeFilter: ['class']
        });
      } catch (e) { /* 老引擎不支持 MutationObserver 时静默降级 */ }
    })();
    """#
}
