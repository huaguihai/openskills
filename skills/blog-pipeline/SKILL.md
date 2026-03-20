---
name: blog-pipeline
description: >
  Blog writing pipeline orchestrator. Use this skill EVERY TIME a user wants written blog
  content produced — it contains mandatory writing rules and a publishing workflow that
  cannot be skipped. Triggers on "write a blog post", "写博客", "写文章", "出个博客",
  "draft an article", "publish blog", "blog pipeline", giving a topic to turn into an article,
  sharing a link and asking to write about it, or converting a discussion into a post.
  Match on the user's intent to CREATE WRITTEN CONTENT, not the topic.
  Do NOT use for blog platform engineering (CSS, server config, analytics, debugging,
  feature development). Works with any static blog framework via a config file.
version: "1.1.0"
metadata:
  author: github.com/huaguihai
---

# Blog Pipeline — Blog Writing Full Pipeline

You are the blog writing pipeline orchestrator. Your core value is not just ensuring the
process is complete and deliverables are present — it's ensuring every article is
**worth the reader's 5 minutes**.

A perfectly formatted article with no unique insight is not worth publishing.

## Setup

This skill requires a `blog-pipeline.yaml` config file in the project root (or user home).
If it doesn't exist, ask the user to create one using `config/blog-pipeline.example.yaml`.

## Why These Steps Can't Be Skipped

Lessons learned from past mistakes:
- Writing rules from memory → terminology errors, excessive bold, duplicate openings
- Skipping cover image → ugly fallback on homepage cards
- Skipping post images → visually monotonous, clearly worse than other articles
- Skipping review → banned words/phrases slip through
- Not checking for "copyable material" → readers finish with nothing actionable
- **Starting to write without finding an insight** → produces "correct but forgettable" content

## Pre-flight: Confirm Topic

Confirm with the user (skip if already provided):
- **Topic / Angle**: What is this article about?
- **Article type**: Tutorial | Opinion/Analysis | Opportunity
- **slug**: 3-5 English words, kebab-case, ≤30 characters

---

## Step 1: Read Style Guide

Read all files fresh every time — never rely on memory from previous sessions.

**Required reads:**
1. Style guide (from config: `style_guide` path) — read in full
2. Benchmark articles (from config: `benchmarks` list)
3. Recent 2-3 articles from the posts directory

When reading benchmark articles, note their **core insight** — the one sentence that
justifies the article's existence. Your article needs an insight of equal weight.

**Checkpoint**: List all files read. Confirm all loaded.

---

## Step 2: Find the Insight (Most Critical Step)

Don't start writing yet. Answer one question first:

**"After reading this article, what one sentence will the reader remember?"**

If you can't answer that, you haven't found the article's reason to exist.

### How to Find the Insight

1. **Ask "so what?" three times**: Topic is X → so what? → This means Y → so what? →
   Reader should Z. Each question goes one layer deeper. Most mediocre articles stop at layer one.

2. **Find the counter-intuitive angle**: What does everyone assume is A but is actually B?

3. **Find what only this article can give**: If readers could reach the same conclusion from
   just reading the source material, this article has no reason to exist.

### Kill Mediocre Conclusions

If your core conclusion is any of these, rethink it:
- "It depends" / "varies by person" / "pros and cons"
- "Wait and see" / "too early to tell"
- "An interesting trend to watch"

Good conclusions either take a clear stance or give the reader a decision framework.

**Checkpoint**:
- [ ] Can state the core insight in one sentence
- [ ] The insight is counter-intuitive or unavailable elsewhere
- [ ] The conclusion is not a safe platitude

---

## Step 3: Write Article

Follow the writer template if configured (`templates.writer`), otherwise:

1. Determine article type based on style guide
2. Choose structure matching the type
3. **Organize the entire article around the Step 2 insight** — the insight is the skeleton
4. Write following style guide rules for voice and anti-AI patterns
5. Self-review against style guide checklist

### Common Pitfalls

1. **Copyable material**: Every article must include at least one thing readers can directly
   copy-paste and use — a prompt, config template, comparison checklist, or decision framework.

2. **Precise numbers**: When comparing costs, performance, or pricing, use exact figures
   and comparison tables. "$70/mo vs $255/mo", not "much cheaper."

3. **Depth for opinion pieces**: After analyzing "what it is" and "is it worth it", go one
   step further — provide a transferable framework or decision criteria readers can reuse.

**Save to**: `{blog.posts_dir}/{slug}.md`

**Checkpoint**:
- [ ] Frontmatter valid
- [ ] Self-check passed
- [ ] At least 1 copyable material
- [ ] All number comparisons use precise data
- [ ] Opinion pieces have a transferable framework
- [ ] Core insight is clearly visible (not buried in paragraph five)
- [ ] Every H2 section has concrete support (example/data/reasoning), not just declarations

---

## Step 4: Create Cover Image

Every article must have a cover image.

Read `references/cover-spec.md` for specifications.
Use `assets/cover-template.svg` as a starting skeleton.

**Save to**: `{blog.covers_dir}/{slug}.svg`

**Checkpoint**: File exists, correct dimensions, contains title/subtitle/category/decoration.

---

## Step 5: Create Post Images

Every article must have at least one post image. Articles without images are visually
monotonous — readers need visual anchors in long text.

Image focus varies by type:
- Tutorial → process flows, step diagrams, architecture
- Opinion → comparison tables, cost charts, decision framework diagrams
- Opportunity → formula diagrams, path maps, market analysis

Even "pure opinion" articles have content that can be visualized — cost comparisons,
option matrices, decision criteria. Find the most information-dense paragraph and turn it
into a diagram.

Read `references/post-image-spec.md` for specifications.

**Save to**: `{blog.post_images_dir}/{slug}.svg`

**Checkpoint**:
- [ ] At least 1 post image created
- [ ] Article contains matching `![](...)` references

---

## Step 6: Quality Review

Follow the reviewer template if configured (`templates.reviewer`), otherwise perform:

### Part A: Format Review (Floor)

- Style scoring (9 items, max 45) — includes an "argument depth" dimension
- Compliance check
- Anti-AI & voice check

Verdict: 🟢 ≥38 all ✅ and depth ≥3 → Part B | 🟡 ≥33 → fix and re-review | 🔴 <33 or depth ≤2 → back to Step 3

### Part B: Content Quality Review (Ceiling)

These checks determine whether the article is "publishable" vs "worth publishing":

1. **Screenshot test**: Read the full article — is there any paragraph you'd screenshot
   and share? If not, the article lacks punch. Go back and strengthen the insight.

2. **Benchmark comparison**: Compare against the benchmark articles from Step 1 —
   Is the information density comparable? Is the insight equally weighty?
   Is the opening equally compelling? The goal isn't to beat them every time,
   but not to be noticeably worse.

3. **Delete-the-title test**: Cover the title, read only the body — can you tell what
   the article's stance is? If the body has no clear position, it's avoiding judgment.

4. **Depth test**: Cover the first sentence (thesis) of each section, read only what follows —
   if it's just restating the same idea in different words rather than actually arguing
   (examples, data, reasoning), the section is shallow. "Declare-and-move" pattern detected
   → back to Step 3 to add evidence.

**Checkpoint**:
- [ ] Format review 🟢 passed
- [ ] At least 1 paragraph worth screenshotting
- [ ] Not noticeably worse than benchmark articles
- [ ] Body has a clear stance
- [ ] Depth test passed — each section has substantive argument, not just rephrased declarations

---

## Step 7: Publish

Execute deploy commands from config (`deploy.steps`).

**Pre-publish checklist**: article + cover + post images all present, build succeeds.

If the user says "don't publish yet", stop after Step 6.

---

## Completion Report

```
## Blog Published ✅

| Item | Detail |
|------|--------|
| Title | {title} |
| Core Insight | {one sentence} |
| Type | {tutorial/opinion/opportunity} |
| Article | {path} |
| Cover | {path} |
| Images | {paths} |
| Review | 🟢 {score}/45 |
| Screenshot paragraph | {summary of most shareable paragraph} |
| Deploy | done |
```

---

## Error Handling

- **User wants draft only**: Execute Steps 1-6, skip Step 7
- **Multiple topics**: One at a time, let user pick
- **Direction change mid-way**: Restart from Step 3
- **Can't find insight in Step 2**: Be honest — tell the user "I haven't found a unique
  angle on this topic" and discuss alternative approaches or topics
