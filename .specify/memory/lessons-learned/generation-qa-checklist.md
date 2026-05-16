# Generation QA Checklist (pre-delivery)

**Status:** Template starter. **Recommended** as a required Quality Gate in your project's constitution. Customize for your project — keep what applies, drop what doesn't.

This checklist consolidates recurring failure modes when Claude generates artifacts (Word docs, PowerPoint, Excel, multi-page handouts, reports) from briefs / transcripts / source documents. Run through every item before declaring done. **The default failure mode of LLM generation is plausible-looking output that quietly violates one of these.**

---

## 1. Source fidelity (when input is verbatim source)

**Applies when**: input is a long-form source document (academic paper, transcript, multi-week study series, legal text, prior work product) whose value depends on preserving the original wording.

- [ ] **Word-count check ≥ 85% of source**. Generated docs that are noticeably shorter than the source have been silently paraphrased.
  ```bash
  # Source
  wc -w source.txt

  # Generated docx body (requires python-docx — see Office skills setup)
  python3.13 -c "from docx import Document; d=Document('out.docx'); print(len(' '.join(p.text for p in d.paragraphs).split()))"

  # If you also have footnotes, include those (see source-fidelity-when-generating-docs.md if present)
  ```
- [ ] **Footnotes / citations preserved at full length** — not summarized to one-liners.
- [ ] **Section structure preserved** — original subsections present, in original order.
- [ ] **Added navigation headings flagged** — if you add section headings the original lacked (for reader ergonomics), say so somewhere or be ready to strip them.

**Why item #1**: Compression is the LLM's strongest default. It happens silently — the output looks valid, only word-count comparison catches it.

---

## 2. Proper-noun and transcription verification

**Applies when**: input came from OCR, YouTube auto-captions, or any speech-to-text source.

- [ ] **Personal names** — spouses, children, close colleagues. Auto-transcription mishears these constantly. Verify against ground truth.
- [ ] **Institution and place names** — company names, university names, city names. Common errors: similar-sounding substitutions.
- [ ] **Foreign / transliterated words** — Greek, Hebrew, Latin, scientific terms.
- [ ] **Quoted source text** — auto-transcription paraphrases quotations; verify against the actual source (correct edition, correct translation).
- [ ] **Cross-check against authoritative source** where one exists.

---

## 3. Audience-appropriate framing

**Applies when**: the artifact will be delivered to a specific audience (clients, executives, students, general public, etc.).

- [ ] **Inline academic citations belong in academic papers**, not in lay material. Move them to a Further Reading / Resources section where curious readers can find them.
- [ ] **Jargon defined on first use** OR replaced with a plain-English equivalent.
- [ ] **Technical depth matches the room** — don't drop seminary / engineering / legal / medical depth into a general audience.
- [ ] **Tone matches the audience** — pastoral, professional, conversational, academic — pick one and stay consistent.
- [ ] **No hedge phrases** like "many scholars believe…" / "some experts say…" — be specific or omit.

---

## 4. Title / naming vision alignment

**Applies when**: the artifact will be delivered inside a specific organizational context with stated mission language.

- [ ] **Does the title use the language the organization uses?** Generic titles are weaker than vision-aligned ones. Example: rewrite "How to Use This Tool" → "Driving [Vision Pillar] with [Tool]" if the org has a named mission pillar.
- [ ] **Does the framing reinforce the organization's stated mission / values / current strategy?**
- [ ] **File names match the title** — rename docx/pptx/xlsx file names AND any cross-references in surrounding docs (README, spec, lessons-learned).
- [ ] **Folder names** — flag and document if folder name doesn't match content (acceptable to leave for history continuity; not acceptable to silently let drift).

---

## 5. Editorial-pass transparency restraint

**Applies when**: artifact has cleanups (OCR fixes, name corrections, translation fixes, formatting normalizations) the audience doesn't need to know about.

- [ ] **Make cleanups silently in the body** — don't add a foreword listing every fix.
- [ ] **Don't apologize for the source** — "this was auto-transcribed and may contain errors" is unhelpful framing for a recipient who just wants to read the document.
- [ ] **Trust the audience to see a clean document.**
- [ ] **Disclosure threshold**: only flag editorial intervention if (a) it materially changed meaning, or (b) the recipient explicitly asked about provenance.

**Why**: A "what I changed" foreword signals "this is AI-touched / unfinished" unnecessarily. The clean fix is the deliverable; meta-commentary is noise.

---

## 6. Surrounding-document consistency

**Applies when**: substantive changes were made to an artifact AND that artifact is referenced from cover notes, READMEs, specs, or indexes.

- [ ] **Cover notes / READMEs that name the artifact** — updated to reflect the current title, length, and contents.
- [ ] **Spec files that describe deliverables** — updated row in the deliverables table.
- [ ] **Page counts, sample lists, file names** — all in sync with the actual generated files.
- [ ] **Index files** (`.specify/memory/lessons-learned/README.md`, table of contents files) — updated.
- [ ] **Cross-references to renamed artifacts** — run `grep -r "old-name"` to find stragglers.

---

## 7. Visual layout QA for slides and visually-formatted docs

**Applies when**: the artifact's value depends on visual layout (slides, multi-column handouts, infographics, branded docs).

- [ ] **Render to images** for inspection (requires LibreOffice + poppler — see Office skills setup):
  ```bash
  soffice --headless --convert-to pdf --outdir /tmp out.pptx
  pdftoppm -jpeg -r 100 /tmp/out.pdf /tmp/slide-imgs/slide
  ```
- [ ] **USE A SUBAGENT for visual inspection** — even for 2-3 slides. You'll see what you expect, not what's there. Fresh eyes catch overlaps, footer collisions, text overflow. (This is the official Anthropic `pptx` skill's own discipline.)
- [ ] **Specifically watch for**: text overlapping shapes; text running through decorative lines; footer collisions with content; columns of uneven height; insufficient margins (<0.5"); low-contrast text; text wrapping mid-number or mid-name; leftover placeholder content from templates.
- [ ] **At least one fix-and-verify cycle** — never declare done on the first render. Real example: a 22-slide deck had 5 layout bugs on first pass; second pass after fixes was clean.

---

## 8. Brand / doctrinal / editorial alignment

**Applies when**: the artifact is delivered inside an organization with stated positions (brand guidelines, doctrinal statements, editorial style guide).

- [ ] **Honor the organization's official positions** — if the org has a brand book, statement of faith, or style guide, the artifact must align.
- [ ] **Flag positions that are personal vs. organizational** — where the org is silent or has multiple views, don't speak for them; mark personal framing as personal.
- [ ] **The brief's alignment table** (if any) honored row-by-row.
- [ ] **No conflicting framings** — generated text should not contradict positions the org has staked out.

---

## Running the checklist

For any substantive generation:

1. Generate the artifact.
2. Run through items 1–8 above, marking each pass / fail.
3. Fix anything that failed.
4. **Re-verify items affected by the fix** — one fix often introduces a new problem (especially visual layout).
5. Only then declare done.

**Default to assuming there are problems.** If you found zero issues on first inspection, you weren't looking hard enough.

---

## Suggested constitution wording

Add something like this to your project's `constitution.md` (under Quality Gates or Per-Topic Workflow):

> **Generation QA Gate (required pre-delivery)**: Any generated artifact (Word doc,
> PowerPoint, Excel, multi-page handout, report) MUST pass the Generation QA
> Checklist before being delivered to a real recipient. Checklist location:
> `.specify/memory/lessons-learned/generation-qa-checklist.md`. The checklist is
> not optional — default to assuming there are problems on every generated
> artifact.

---

## Provenance

This checklist consolidates 8 recurring failure modes surfaced during real
project work (May 2026) generating teaching artifacts (Word docs + PowerPoint
slides) via Claude with Anthropic's official `docx` and `pptx` skills. Each
category corresponds to a specific class of issue that recurred across multiple
generation attempts before being lifted into a checklist item.
