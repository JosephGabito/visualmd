import {
  initMerman,
  parseObject,
  renderSvg
} from './vendor/merman-web/dist/package-entries/render.js';

let ready;
let queue = Promise.resolve();

const ensureReady = () => ready ??= initMerman();

// Flutter calls one global bridge on web, just as it calls one typed renderer
// on native targets. SVG is returned as inert data and never mounted in the
// browser DOM; Flutter owns painting, accessibility, and every interaction.
window.visualMdRenderMermaid = (source, paletteJson) => {
  const task = queue.then(async () => {
    await ensureReady();
    const palette = JSON.parse(paletteJson);
    const options = JSON.stringify({
      version: 2,
      presentation: {
        theme: {
          appearance: palette.dark ? 'dark' : 'light',
          font_family: 'Inter, system-ui, sans-serif',
          font_size: '14px',
          roles: {
            canvas: palette.canvas,
            surface: palette.surface,
            'surface-alt': palette.canvas,
            text: palette.text,
            'subtle-text': palette.subtleText,
            border: palette.border,
            line: palette.line,
            success: palette.accent
          },
          series_palette: [palette.accent, palette.line, palette.subtleText]
        }
      },
      resources: { profile: 'constrained' },
      svg: {
        pipeline: 'resvg-safe',
        root_background_color: palette.canvas,
        drop_native_duplicate_fallbacks: true,
        css_override_policy: 'strip-existing-important'
      }
    });
    const semantic = parseObject(source, options);
    return JSON.stringify({
      svg: renderSvg(source, options),
      title: semantic.accTitle || null,
      description: semantic.accDescr || null
    });
  });

  // A failed diagram must not poison the renderer for the next block.
  queue = task.catch(() => undefined);
  return task;
};
