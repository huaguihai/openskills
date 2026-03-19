# Cover Image SVG Specification

## Dimensions
- **Width**: As defined in `blog-pipeline.yaml` → `cover.width` (default: 660)
- **Height**: As defined in `blog-pipeline.yaml` → `cover.height` (default: 300)
- **Format**: SVG

## Style: dark-warm (default)

### Color Scheme
- **Background gradient**: `#44403C` → `#1C1917` (warm dark, top-left to bottom-right)
- **Accent gradient**: `#EA580C` → `#F59E0B` (orange to amber)
- **Title text**: `#FAFAF9` (near white)
- **Subtitle text**: `#A8A29E` (muted stone)
- **Category label**: `#EA580C` (brand orange)
- **Tag capsules**: `#57534E` bg with opacity 0.4, `#D6D3D1` text

### Layout (full-width text + bottom-right decoration)
```
┌─────────────────────────────────────┐
│ ▌ Title Line 1                      │
│ ▌ Title Line 2                      │
│                                     │
│   Subtitle (short excerpt)          │
│   ─────────────────                 │
│   Category Label             [Icon] │
│                              [Art]  │
│   [Tag1] [Tag2] [Tag3]             │
│                                     │
│▓▓▓▓▓▓▓▓▓▓▓▓ Accent bar ▓▓▓▓▓▓▓▓▓▓│
└─────────────────────────────────────┘
```

### Required Elements
1. Dark gradient background + subtle dot texture (opacity 0.06)
2. Left accent bar (vertical, x=50, width=4, gradient)
3. Title (font-size 22, bold, split into tspan lines from x=70)
4. Subtitle (font-size 13, one line)
5. Divider line (x1=70 to x2=420)
6. Category label (font-size 11, orange)
7. 2-3 tag capsules (rounded rect + centered text)
8. Decorative icon in bottom-right corner (x≥480, y≥180, topic-related)
9. Bottom accent bar (full width, height 7)
10. Optional watermark (bottom-right, font-size 9, opacity 0.5)

### Font Stack
```
CJK: 'PingFang SC','Hiragino Sans GB','Microsoft YaHei',sans-serif
Latin: -apple-system,'Segoe UI',sans-serif
```

## Template
See `assets/cover-template.svg` for a ready-to-customize skeleton with placeholders.
