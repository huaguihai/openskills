# Post Image SVG Specification

## Dimensions
- **Width**: As defined in `blog-pipeline.yaml` → `post_image.width` (default: 660)
- **Height**: As defined in `blog-pipeline.yaml` → `post_image.height` (default: 400)
- **Format**: SVG

## When to Create Post Images
- Process/workflow that benefits from visualization
- Comparison/classification needing a table or chart
- Formula/model that needs diagramming
- Architecture/layer relationships
- Skip for pure opinion or narrative articles

## Style: light-card (default)

### Color Scheme
- **Background**: `#FAFAFA` (warm white)
- **Card**: White, border-radius 10-12px, drop shadow
- **Brand colors**:
  - Blue `#2563EB` (information, process flows)
  - Orange `#EA580C` (emphasis, brand)
  - Green `#16A34A` (success, positive)
  - Purple `#9333EA` (optional, secondary)
- **Text**: `#1C1917` (title), `#44403C` (body), `#78716C` (secondary)
- **Borders**: `#E7E5E4`

### Layout Rules
- **Vertical top-to-bottom** flow (no Z-pattern or horizontal layouts)
- One core concept per image
- Mobile-friendly: minimum text size 11px
- Use arrows (`↓`) between vertical blocks to show flow

### Font Stack
```
font-family="-apple-system,'Segoe UI',sans-serif"
```

### Shadow Definition (reusable)
```xml
<defs>
  <filter id="shadow" x="-5%" y="-5%" width="110%" height="115%">
    <feDropShadow dx="0" dy="2" stdDeviation="4" flood-color="#000" flood-opacity="0.06"/>
  </filter>
</defs>
```

## Common Layouts

### Vertical Layers (architecture, pipeline)
Three colored blocks stacked vertically with arrows between them.
Each block has a colored header bar and content area.

### Before/After Comparison
Two columns side by side. Left uses gray/red tones, right uses blue/green tones.

### Step-by-step Process
Numbered circles connected by lines, each with a label and description.

## Referencing in Articles
```markdown
![Description text](/images/posts/{slug}.svg)
```
Multiple images: `{slug}-2.svg`, `{slug}-3.svg`

## Template
See `assets/post-image-template.svg` for a ready-to-customize skeleton.
