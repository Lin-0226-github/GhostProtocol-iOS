import Foundation

/// 针对站点的渲染兼容补丁。
///
/// 站点用 Tailwind v4 构建，产出大量 iOS 16+ 才支持的 CSS 语法。
/// WKWebView 遇到不认识的语法时不会降级，而是**整条声明丢弃**，
/// 于是出现肉眼可见的破版。这里在运行时做兼容。
enum SitePatches {

    /// Tailwind v4 把方向渐变写成 `linear-gradient(to right in oklab, ...)`，
    /// `in oklab` 插值语法需要 Safari 16.4+。旧版 WebKit 无法解析，
    /// 会**整条丢弃 background-image**，导致全站 488 处渐变一起消失
    /// （横幅两端渐隐、卡片光晕、按钮底色都会退化成实心或全透明）。
    ///
    /// 这里把 --tw-gradient-position 里的插值空间去掉，退回默认 sRGB 插值，
    /// 渐变本身不受影响，只是颜色过渡不再走 oklab。
    static let gradientFallback = #"""
    (function () {
      if (window.__ghqGradientPatch) { return; }
      window.__ghqGradientPatch = true;

      var css = [
        '.bg-gradient-to-t,.bg-linear-to-t{--tw-gradient-position:to top!important}',
        '.bg-gradient-to-tr,.bg-linear-to-tr{--tw-gradient-position:to top right!important}',
        '.bg-gradient-to-r,.bg-linear-to-r{--tw-gradient-position:to right!important}',
        '.bg-gradient-to-br,.bg-linear-to-br{--tw-gradient-position:to bottom right!important}',
        '.bg-gradient-to-b,.bg-linear-to-b{--tw-gradient-position:to bottom!important}',
        '.bg-gradient-to-bl,.bg-linear-to-bl{--tw-gradient-position:to bottom left!important}',
        '.bg-gradient-to-l,.bg-linear-to-l{--tw-gradient-position:to left!important}',
        '.bg-gradient-to-tl,.bg-linear-to-tl{--tw-gradient-position:to top left!important}'
      ].join('');

      var style = document.createElement('style');
      style.id = 'ghq-gradient-fallback';
      style.textContent = css;
      (document.head || document.documentElement).appendChild(style);
    })();
    """#

    /// Tailwind v4 的透明度修饰类（`bg-primary/[0.07]`、`border-primary/40`、`text-muted-foreground/70`）
    /// 编译成两条同选择器规则：
    ///   1) <prop>: var(--primary)                                  ← 纯色兜底
    ///   2) <prop>: color-mix(in oklab, var(--primary) 7%, transparent)  ← 正确值
    ///
    /// `color-mix()` 需要 Safari 16.2+。不支持时第 2 条被丢弃，直接落到纯色兜底：
    /// 背景从 7% 淡绿变成不透明亮绿（盖住内容），边框从 40% 变成纯绿（显得过亮）。
    ///
    /// 这里按类名里声明的 alpha 重新写回 rgba()。宿主支持 color-mix() 时，
    /// 计算值本来就是半透明，会被自动跳过，不会重复干预。
    static let alphaFallback = #"""
    (function () {
      if (window.__ghqAlphaPatch) { return; }
      window.__ghqAlphaPatch = true;

      var COLORS = 'background|foreground|card|card-foreground|popover|popover-foreground'
        + '|primary|primary-foreground|secondary|secondary-foreground'
        + '|muted|muted-foreground|accent|accent-foreground'
        + '|destructive|destructive-foreground|border|input|ring|black|white';
      var ALPHA = '(?:\\[(0?\\.\\d+)\\]|(\\d{1,3}))';
      var HEAD = '(?:^|\\s)';

      var RULES = [
        { re: new RegExp(HEAD + 'bg-(' + COLORS + ')/' + ALPHA + '(?=\\s|$)'),
          read: 'backgroundColor', write: 'backgroundColor' },
        { re: new RegExp(HEAD + 'text-(' + COLORS + ')/' + ALPHA + '(?=\\s|$)'),
          read: 'color', write: 'color' },
        { re: new RegExp(HEAD + 'border-(' + COLORS + ')/' + ALPHA + '(?=\\s|$)'),
          read: 'borderTopColor', write: 'borderColor' }
      ];

      var pending = new Set();
      var frame = 0;

      function alphaOf(m) {
        if (m[2] != null) { return parseFloat(m[2]); }
        if (m[3] != null) { return parseInt(m[3], 10) / 100; }
        return null;
      }

      function patch(el) {
        if (!el || el.nodeType !== 1 || !el.getAttribute) { return; }
        var cls = el.getAttribute('class');
        if (!cls || cls.indexOf('/') < 0) { return; }
        var cs = window.getComputedStyle(el);

        for (var i = 0; i < RULES.length; i++) {
          var rule = RULES[i];
          var m = rule.re.exec(cls);
          if (!m) { continue; }
          var a = alphaOf(m);
          if (!(a > 0 && a < 1)) { continue; }

          var parts = (cs[rule.read] || '').match(/[\d.]+/g);
          if (!parts || parts.length < 3) { continue; }
          // 已经是半透明 → 宿主解析正常，不动
          if (parts.length > 3 && parseFloat(parts[3]) < 0.999) { continue; }

          el.style[rule.write] =
            'rgba(' + parts[0] + ',' + parts[1] + ',' + parts[2] + ',' + a + ')';
        }
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

    /// 摇一摇触发的诊断浮层：把告警横幅及其 8 层祖先的关键样式打到屏幕上，
    /// 便于在没有 Safari 检查器的情况下定位仍然错位的元素。
    static let diagnostic = #"""
    (function () {
      var target = null;
      var nodes = document.querySelectorAll('div,span,p,h1,h2,h3,section,header');
      for (var i = 0; i < nodes.length; i++) {
        var txt = nodes[i].textContent || '';
        if (txt.indexOf('红色警报') >= 0 || txt.indexOf('亚洲区第三号') >= 0) {
          if (!target || nodes[i].children.length < target.children.length) {
            target = nodes[i];
          }
        }
      }
      if (!target) { target = document.body; }

      var out = [];
      var n = target;
      for (var d = 0; d < 8 && n; d++) {
        var cs = window.getComputedStyle(n);
        var r = n.getBoundingClientRect();
        out.push('[' + d + '] <' + n.tagName.toLowerCase() + '> ' +
                 (n.className || '').toString().slice(0, 140));
        out.push('    x=' + Math.round(r.left) + ' w=' + Math.round(r.width) +
                 ' h=' + Math.round(r.height));
        out.push('    bg=' + cs.backgroundColor +
                 '  img=' + (cs.backgroundImage || 'none').slice(0, 60));
        out.push('    pl=' + cs.paddingLeft + ' pr=' + cs.paddingRight +
                 ' ml=' + cs.marginLeft + ' mr=' + cs.marginRight);
        out.push('    pos=' + cs.position + ' ov=' + cs.overflow +
                 ' disp=' + cs.display + ' z=' + cs.zIndex);
        n = n.parentElement;
      }

      var box = document.createElement('pre');
      box.textContent = out.join('\n');
      box.style.cssText = 'position:fixed;inset:0;z-index:2147483647;background:#000;'
        + 'color:#0f0;font:11px/1.5 ui-monospace,monospace;padding:16px;overflow:auto;'
        + 'white-space:pre-wrap;word-break:break-all;-webkit-user-select:text;';
      box.addEventListener('click', function () { box.parentNode.removeChild(box); });
      document.body.appendChild(box);
    })();
    """#
}
