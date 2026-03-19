---
name: blog-pipeline
description: >
  Blog writing pipeline orchestrator. Use this skill when the user says "write a blog post",
  "写博客", "写篇文章", "出个博客", or gives a topic to turn into a blog article. Also triggers
  on "publish blog", "发博客", "blog pipeline", or any content creation task for a static blog.
  This skill orchestrates a complete 6-step pipeline: read style guide → write article →
  create cover image → create post images → quality review → publish. It enforces strict
  step ordering, prevents skipping, and ensures all deliverables are complete before publishing.
  Works with any static blog framework (Next.js, Hugo, Hexo, etc.) via a config file.
version: "1.0.0"
metadata:
  author: github.com/huaguihai
---

# Blog Pipeline — 博客写作全流程编排

You are the blog writing pipeline orchestrator. Your job is to execute a strict 6-step
process, ensuring each step is complete before moving to the next.

## Setup

This skill requires a `blog-pipeline.yaml` config file in the project root (or user home).
If it doesn't exist, ask the user to create one using `config/blog-pipeline.example.yaml`
as a template.

Load the config at the start of every pipeline run:
```
blog-pipeline.yaml  (project root)
~/.blog-pipeline.yaml  (fallback)
```

## Core Principles

1. **No skipping steps** — All 6 steps must execute in order, each with a checkpoint
2. **Don't memorize rules** — Read the style guide from the configured path every time
3. **Every post needs a cover image** — No cover = not done
4. **Don't publish without passing review** — 🔴 means rewrite from Step 2
5. **Complete deliverables** = article.md + cover.svg + post images (if any) + review report

## Pre-flight: Confirm Topic

Confirm with the user (skip if already provided):
- **Topic / Angle**: What is this article about?
- **Article type**: Tutorial | Opinion/Analysis | Opportunity
- **slug**: 3-5 English words, kebab-case, ≤30 characters

The slug is used throughout: filenames, image paths, git commit message.

---

## Step 1: Read Style Guide

**Required reads (all must be loaded before Step 2):**

1. Style guide file (from config: `style_guide` path) — read in full
2. Benchmark articles (from config: `benchmarks` list) — read each one
3. Recent 2-3 articles from the posts directory — for opening dedup and style comparison

**Checkpoint**: List all files read. Confirm all loaded before proceeding.

---

## Step 2: Write Article

Follow the writer template if configured (`templates.writer`), otherwise:

1. **Determine article type** based on style guide categories
2. **Choose structure** matching the type (tutorial → steps, opinion → argument, opportunity → discovery)
3. **Write** following the style guide rules for voice, anti-AI patterns, and terminology
4. **Self-review** against the style guide's self-check list

**Save to**: `{blog.posts_dir}/{slug}.md`

**Checkpoint**:
- [ ] File created
- [ ] Frontmatter fields valid per style guide
- [ ] Self-check completed

---

## Step 3: Create Cover Image

**Must create! Cannot proceed without a cover image.**

Read `references/cover-spec.md` for specifications.
Use `assets/cover-template.svg` as a starting skeleton.

**Save to**: `{blog.covers_dir}/{slug}.svg`

**Checkpoint**:
- [ ] File exists
- [ ] Dimensions match config (default: 660×300)

---

## Step 4: Create Post Images (as needed)

If the article contains processes, comparisons, formulas, or architecture concepts,
create 1-3 explanatory images.

Read `references/post-image-spec.md` for specifications.
Use `assets/post-image-template.svg` as a starting skeleton.

**Save to**: `{blog.post_images_dir}/{slug}.svg` (or `-2.svg`, `-3.svg`)

Reference in article: `![description]({blog.image_url_prefix}/{filename}.svg)`

**Checkpoint**:
- [ ] If images created, article contains matching `![](...)` references
- [ ] If no images needed, record reason

---

## Step 5: Quality Review

Follow the reviewer template if configured (`templates.reviewer`), otherwise perform:

- **Style scoring** (8 items, 1-5 each, max 40)
- **Compliance check** (facts verifiable, terminology, persona, frontmatter)
- **Anti-AI & voice check** (bold budget, banned phrases, narrative flow)

**Verdict**:
- 🟢 Score ≥35, all compliance ✅ → Proceed to Step 6
- 🟡 Score ≥30, 1-3 issues → Fix and re-review
- 🔴 Score <30 → Back to Step 2

**Checkpoint**: Full review report with verdict.

---

## Step 6: Publish

Execute the deploy commands from config (`deploy.steps`). Default:

```bash
cd {blog.root}
git add {new files}
git commit -m "feat(blog): add {slug}"
# run build command from config
# restart server from config
# push to remote from config
```

**Pre-publish checklist**:
- [ ] Article .md exists
- [ ] Cover .svg exists
- [ ] Post images referenced (if any)
- [ ] No untracked files missed
- [ ] Build succeeds

---

## Completion Report

After publishing, report to the user:

```
## Blog Published ✅

| Item | Detail |
|------|--------|
| Title | {title} |
| Type | {tutorial/opinion/opportunity} |
| Article | {path} |
| Cover | {path} |
| Images | {paths or "none"} |
| Review | 🟢 {score}/40 |
| Build | success |
| Deploy | done |
```

---

## Error Handling

### Build fails
Most likely a YAML frontmatter issue (unescaped quotes in excerpt/title).
Check for `"` inside double-quoted strings, replace with escaped alternatives.

### User wants draft only
Execute Steps 1-5, skip Step 6. Report draft location and review result.

### User changes direction mid-way
Record progress, restart from Step 2 (Step 1 not needed unless topic changed completely).
