# Skill Librarian (`skill-lib`)

**Cut startup skill context overhead by 90%+ in Claude Code, Google Antigravity, OpenCode, and Codex — with zero MCP daemons and zero external dependencies.**

---

## GitHub Repository Metadata

- **Repository Name**: `psthi/skill-librarian`
- **Short Description (About)**: Zero-daemon, two-tier on-demand skill router and CLI manager that eliminates `SKILL.md` startup context bloat (~88–91% token reduction) in Claude Code, Antigravity, and OpenCode.
- **Topics / Tags**: `claude-code`, `agent-skills`, `context-window`, `token-optimization`, `ai-agents`, `antigravity`, `opencode`, `prompt-engineering`, `cli`, `developer-tools`

---

## The Problem: Startup Skill Bloat

Modern AI coding harnesses (`Claude Code`, `Antigravity`, `OpenCode`, `Codex`, `Hermes`) automatically scan every installed skill folder (`~/.claude/skills/*/SKILL.md` or `~/.agents/skills/*/SKILL.md`) at session startup and inject each skill's full YAML `description` into the system prompt on **every turn**.

When you accumulate 25–40 specialized domain skills (video pipelines, SEO automation, Stripe CLI, Temporal SDK, n8n workflows, web scrapers, Lottie animations, document converters), those descriptions consume **3,000+ tokens on every single message**—even when 95% of your sessions only touch 0–2 of them. Worse, dozens of competing trigger descriptions cause prompt distraction.

## Why Not an MCP Server?

A common temptation is to build a local `stdio` MCP server (`list_skills`, `search_skills`, `load_skill`) to serve offloaded skills. In practice, an MCP gateway introduces four drawbacks:

1. **Trigger Blindness**: If a router skill's frontmatter only says *"Access specialized domain skills on demand"*, the LLM does not know *which* domains exist in the library. It either fails to check the library (false negative) or calls `list_skills` on every prompt "just in case" (wasting a turn and adding latency).
2. **MCP Schema & Daemon Overhead**: Eager MCP loaders inject 300–450 tokens of JSON tool schemas into the system prompt and spawn a persistent Node.js/Python process per session. Lazy MCP loaders require 3–4 sequential tool calls (read schema -> list skills -> load skill) for what should be a single file read.
3. **Broken Relative Asset Paths**: Many skills bundle `scripts/`, `references/`, or `examples/` alongside `SKILL.md`. Streaming raw markdown text over MCP strips the filesystem directory context needed to run bundled helper scripts.
4. **Redundant Tooling**: Every CLI agent already has a native, fast `Read` / `read_file` tool.

## The Solution: Two-Tier Native Router + Auto-Indexed Trigger Map

`skill-librarian` uses a zero-daemon two-tier architecture:

```text
~/.claude/skills/ (or ~/.agents/skills/)     <-- ACTIVE STARTUP CONTEXT (~270 tokens total)
├── skill-librarian/
│   └── SKILL.md                             <-- Compact auto-generated trigger map + path index
└── (2-3 core daily workflow skills)

~/.agent-skills-library/                     <-- OFFLINE WAREHOUSE (0 startup tokens)
├── stripe-cli/
│   └── SKILL.md
├── temporal-developer/
│   ├── SKILL.md
│   └── references/
├── dotlottie-web/
│   ├── SKILL.md
│   ├── scripts/
│   └── examples/
└── ... (30+ specialized domain skills)
```

1. **Two-Stage Routing (Fast-Path + Fallback Index)**:
   - **Stage 1 (Startup Frontmatter — ~280 tokens)**: `skill-lib sync` compiles a compact list of installed library skill names (grouping multi-skill families like `n8n-* (4)` and supporting optional micro-hints via `skill-lib hint`). For self-descriptive skills (`stripe-cli`, `temporal-developer`, `seo-audit`), the agent jumps directly to `~/.agent-skills-library/<skill>/SKILL.md` in 1 step. For any unfamiliar domain or opaque skill name, the frontmatter fallback rule directs the agent to read `skill-librarian/SKILL.md` first.
   - **Stage 2 (Body Index — 0 Startup Tokens)**: Because harnesses only load YAML frontmatter at startup, the Markdown body of `skill-librarian/SKILL.md` stores the **complete, untruncated descriptions** of all library skills at **zero startup token cost**—preserving every trigger phrase once opened.
2. **Direct Native `Read` Execution**: When a prompt touches a library domain, the agent reads `~/.agent-skills-library/<skill>/SKILL.md` via its native `Read` tool and resolves any bundled `scripts/` or `references/` relative to that folder.
3. **Zero-Touch Auto-Offloading (`SessionStart` Hook + `.keep.json`)**: When you install new skills via `npx skills add` or similar tools, they land in your active skills directory. `skill-lib init` records your pinned active skills in `~/.agent-skills-library/.keep.json` and registers a `SessionStart` hook (`skill-lib sync --quiet`) in `~/.claude/settings.json` that automatically offloads and indexes any newly installed unpinned skills on session start—with zero manual commands required.
4. **3-Tier Skill Protection & Plugin Declutter Policy**:
   - **Tier 1 (Protected Core — Always `"on"`)**: Never disables essential cross-cutting skills (`context-mode:context-mode`, `opencode:*` delegation routers, `claude-mem:mem-search` & `smart-explore`, plus any skill pinned via `skill-lib protect <skill-id>` or `skill-lib activate <name>`).
   - **Tier 2 (Operator Slash Commands — `"user-invocable-only"` / `disable-model-invocation: true`)**: Marks manual admin/diagnostic plugin commands (`/context-mode:ctx-stats`, `/context-mode:ctx-doctor`, `/claude-mem:handoff`, `/claude-mem:make-plan`, etc.) as user-invocable only—removing ~9,600 chars of prompt bloat while keeping every `/slash` command available when typed by the user.
   - **Tier 3 (Domain & Duplicate Plugin Skills — Offloaded to Library)**: Harvests domain plugin skills (`hostinger-*`, `obsidian-*`, `skill-creator`) into `~/.agent-skills-library/` for on-demand loading via `skill-librarian` and mutes duplicate/domain plugin bloat (`disable-model-invocation: true`) in `~/.claude/plugins/{cache,synced}/`.
5. **Automatic Zero-Prompt Claude Code Permissions**: `skill-lib init` adds `Skill(skill-librarian)` and `Read(~/.agent-skills-library/**)` to `~/.claude/settings.json` so Claude Code can load library skills from any project directory without permission prompts.

---

## How Keyword & Catchphrase Triggering Works

How a skill gets invoked depends on which tier it belongs to:

### 1. Tier 1 Protected Skills (Immediate 1-Step Trigger on Any Catchphrase)
- **Skills**: `context-mode:context-mode`, `opencode:*` delegation routers, `claude-mem:mem-search`, `claude-mem:smart-explore`, plus your pinned local skills (e.g., `token-efficient-coding`, `obsidian-cli`, `local-ollama-workflows`).
- **Behavior**: Their full descriptions remain in the agent's startup prompt (`skill_listing`), so any keyword or catchphrase inside them (e.g., *"analyze logs"*, *"did we already solve this?"*, *"Playwright snapshot"*, *"outline this file"*) triggers immediately on Turn 1.

### 2. Offline Library Skills in `skill-librarian` (1-Step Fast-Path + 2-Step Fallback Index)
- **Domain Keywords & Hints (1-Step Fast-Path)**: Whenever your prompt includes a keyword matching the startup trigger list in `skill-librarian/SKILL.md`—such as *"GSAP"*, *"ScrollTrigger"*, *"n8n"*, *"Stripe"*, *"Temporal"*, *"Hostinger"*, *"SEO audit"*, *"infographic"*, *"Xiaohongshu/YouTube subtitles"* (`agent-reach (social/youtube/reddit)`), *"Reddit/X trends"* (`last30days (trends/reddit/x)`), or *"whitepaper/PDF"* (`autoreport (reports/pdf)`)—the agent reads `~/.agent-skills-library/<skill>/SKILL.md` directly on Turn 1.
- **Buried Catchphrases Inside Descriptions (2-Step Index Lookup)**: Some skills contain niche trigger phrases inside their description that are not obvious from the folder name alone (for example, *"create a podcast about X"* inside `notebooklm`, or *"Defuddle"* inside `obsidian-defuddle`). For these, the fallback rule in `skill-librarian`'s frontmatter directs the agent to read `skill-librarian/SKILL.md` first, where the **full, untruncated descriptions and catchphrases** of all library skills are stored at zero startup token cost.
- **Promoting Any Catchphrase to 1-Step (`skill-lib hint`)**: If you frequently use a specific catchphrase for an opaque-named library skill, attach a micro-hint so it appears directly in the startup prompt for ~3 tokens:
  ```bash
  skill-lib hint notebooklm "podcast/notebooks"
  ```

### 3. Tier 2 Muted Plugin Slash Commands (Explicit `/slash` Invocation Only)
- **Skills**: Operator/utility plugin commands such as `/context-mode:ctx-stats`, `/context-mode:ctx-doctor`, `/claude-mem:make-plan`, `/claude-mem:handoff`.
- **Behavior**: Because these have `disable-model-invocation: true` (`user-invocable-only`), their descriptions are excluded from the startup prompt—they run **only** when you explicitly type `/context-mode:ctx-stats` or `/claude-mem:make-plan`.
- **Restoring Conversational Catchphrases (`skill-lib protect`)**: If you want any muted plugin skill to auto-trigger on conversational catchphrases instead, promote it to Tier 1:
  ```bash
  skill-lib protect claude-mem:make-plan
  ```

---

## Measured Context Savings & Live Claude Code Benchmark

Tested on a real workstation with **57 local/harvested skills** (`3` core daily skills pinned active + `54` specialized domain skills offloaded to `~/.agent-skills-library/`) and **88 plugin/synced skills**:

| Metric | Before (`skill-lib`) | After (`skill-lib` + 3-Tier Policy) | Savings |
| :--- | :--- | :--- | :--- |
| **Local + Harvested Startup Skills** | 57 skills (`20,257` chars) | 4 skills (`1,558` chars) | **92.3% reduction (`18,699` chars / `~4,675` tokens saved)** |
| **Total Claude Code `skill_listing` Attachment (Local + Plugins + Built-ins)** | 92 skills (`30,003` bytes / `~7,500` tokens) | 19 protected skills (`7,099` bytes / `~1,774` tokens) | **76.3% total reduction (`22,904` bytes / `~5,726` tokens saved)** |
| **Marginal Cost of Installing 8 New `gsap-*` Skills** | +2,595 chars (`~648` tokens) | **+12 chars (`gsap-* (8)`, `~3` tokens)** | **99.5% marginal reduction** |
| **Background Daemons** | 0 | 0 | **0 MCP processes** |

### Live `skill-lib list` Output

```text
=== Pinned Active Skills in ~/.agents/skills (3 + skill-librarian) ===
  [active]  local-ollama-workflows           ( 126 chars) Standardized local Ollama model routing, selection matrix...
  [active]  obsidian-cli                     ( 179 chars) Cheatsheet and execution standard for managing Obsidian...
  [active]  token-efficient-coding           ( 262 chars) Zero-turn local code outline extraction and multi-languag...
  [router]  skill-librarian                  ( 917 chars) On-demand router for 41 library skills

=== Offline Library Skills in ~/.agent-skills-library (41) ===
  [library] agent-reach (social/youtube/reddit) ( 744 chars) Read-only access to platform content: search, read posts...
  [library] anti-ai-slop                     ( 277 chars) Knowledge base from a 9-source compilation on detecting...
  [library] autoreport (reports/pdf)         ( 341 chars) Autonomous short-report, whitepaper, essay, and executive...
  [library] book-to-skill                    ( 432 chars) Converts books and documents (PDF, EPUB, DOCX, HTML, Mark...
  [library] composio-cli                     ( 587 chars) Help users operate the published Composio CLI to find the...
  [library] crawl4ai (scrape/extract)        ( 275 chars) This skill should be used when users need to scrape websi...
  [library] dotlottie-web                    ( 387 chars) Implement Lottie animations using dotLottie runtimes (@lo...
  [library] epic-infographics                ( 525 chars) Create polished, professional infographic images from dat...
  [library] explainer-video                  ( 416 chars) Turn an article URL, PDF, Markdown/text file, Obsidian li...
  [library] firecrawl-scrape                 ( 402 chars) Extract clean markdown from any URL, including JavaScript...
  [library] gsap-core                        ( 541 chars) Official GSAP skill for the core API — gsap.to(), from()...
  [library] gsap-frameworks                  ( 355 chars) Official GSAP skill for Vue, Svelte, and other non-React...
  [library] gsap-performance                 ( 228 chars) Official GSAP skill for performance — prefer transforms...
  [library] gsap-plugins                     ( 352 chars) Official GSAP skill for GSAP plugins — registration, Scr...
  [library] gsap-react                       ( 273 chars) Official GSAP skill for React — useGSAP hook, refs, gsap...
  [library] gsap-scrolltrigger               ( 323 chars) Official GSAP skill for ScrollTrigger — scroll-linked an...
  [library] gsap-timeline                    ( 295 chars) Official GSAP skill for timelines — gsap.timeline(), pos...
  [library] gsap-utils                       ( 228 chars) Official GSAP skill for gsap.utils — clamp, mapRange, no...
  [library] last30days (trends/reddit/x)     ( 246 chars) Research what people actually say about any topic in the ...
  [library] llm-ingestion-compliance         ( 434 chars) Audit and configure a website (emphasis on WordPress) so...
  [library] motion-design                    ( 416 chars) Applies motion design principles to create emotionally-dr...
  [library] n8n-agents-official              ( 769 chars) Use when building or editing any AI feature in n8n: AI Ag...
  [library] n8n-code-nodes-official          ( 363 chars) Use when the user reaches for a Code node, mentions writi...
  [library] n8n-debugging-official           ( 289 chars) Use when an n8n workflow isn't working, errors appear, re...
  [library] n8n-workflow-lifecycle-official  ( 510 chars) Use when starting, designing, organizing, finishing, or s...
  [library] notebooklm                       ( 264 chars) Complete API for Google NotebookLM - full programmatic ac...
  [library] rankmath-seo-automation          ( 142 chars) Knowledge base from Rank Math SEO documentation.
  [library] reverse-engineer-anything        ( 300 chars) Reverse engineer native, managed, Electron/JavaScript, pa...
  [library] seo-audit                        ( 679 chars) When the user wants to audit, review, or diagnose SEO iss...
  [library] stripe-cli                       ( 135 chars) Operational guidelines and CLI cheatsheet for AI agents u...
  [library] temporal-developer               ( 801 chars) Develop, debug, and manage Temporal applications across P...
  [library] windmill                         ( 406 chars) Knowledge base from the official Windmill documentation (...
  ... (+9 additional specialized skills)

=== Context Window Footprint Summary ===
  Previous startup frontmatter: 15,929 chars (~3,982 tokens)
  Current startup frontmatter:  1,484 chars (~371 tokens)
  Net startup context saved:    14,445 chars (~3,611 tokens, 90% reduction)
```

### Live Claude Code End-to-End Verification

Verified in headless mode against `claude` (`Claude Code 2.1.318` / `claude-haiku-5-5`) with `Skill` and `Read` tools enabled:

#### Test 1: Fast-Path Domain Match (`stripe-cli`)
```bash
claude -p "Use skill-librarian to read the stripe-cli skill and list its webhook commands." \
  --allowedTools "Skill,Read"
```
- **Result**: Claude Code matched `stripe-cli` from `skill-librarian`'s startup trigger list, read `~/.agent-skills-library/stripe-cli/SKILL.md` directly via the native `Read` tool with zero permission prompts, and returned the exact webhook forwarding (`stripe listen --forward-to`) and mock event (`stripe trigger <event>`) commands.

#### Test 2: Blind Routing on an Opaque Brand-Named Skill (`agent-reach`)
Prompted **without** mentioning `skill-librarian` or `agent-reach` anywhere in the prompt:
```bash
claude -p "Without searching the web, check my installed skills to tell me the exact command to check which social platforms (like Xiaohongshu or YouTube subtitles) are currently configured and healthy." \
  --allowedTools "Skill,Read"
```
- **Result**: From the startup entry `agent-reach (social/youtube/reddit)`, Claude Code identified `agent-reach` on Turn 1, called `Read("~/.agent-skills-library/agent-reach/SKILL.md")`, and returned the exact health-check commands (`agent-reach doctor --text` and `agent-reach check xiaohongshu --text`).

---

## One-Shot Installation

Requires only **Python 3.8+** (uses 100% standard library — no `pip` packages required).

### Option 1: One-Liner Install & Initialize (Recommended)

Install `skill-lib` to `~/.local/bin/skill-lib`, create `~/.agent-skills-library/`, generate the `skill-librarian` router skill, and configure Claude Code permissions:

```bash
curl -fsSL https://raw.githubusercontent.com/psthi/skill-librarian/main/install.sh | bash
```

Want to immediately offload all existing skills except a few core ones? Pass `--offload-all` and `--keep`:

```bash
curl -fsSL https://raw.githubusercontent.com/psthi/skill-librarian/main/install.sh | bash -s -- --offload-all --keep my-core-skill,another-core-skill
```

### Option 2: Install via `uv` or `pipx`

```bash
uv tool install git+https://github.com/psthi/skill-librarian.git
skill-lib init
```

### Option 3: Git Clone

```bash
git clone https://github.com/psthi/skill-librarian.git
cd skill-librarian
./install.sh
```

---

## CLI Usage (`skill-lib`)

```bash
# View active skills, offline library skills, and token savings
skill-lib list

# Move specific skill(s) out of active context into ~/.agent-skills-library/
skill-lib offload stripe-cli temporal-developer dotlottie-web

# Move ALL active skills into the library except a comma-separated keep list
skill-lib offload --all --keep token-efficient-coding,obsidian-cli

# Promote a library skill back to active startup context
skill-lib activate stripe-cli

# Protect a plugin or local skill ID in Tier 1 so it is never muted by skillOverrides
skill-lib protect context-mode:context-mode claude-mem:mem-search

# Search offline library skills by keyword
skill-lib search temporal

# Print a library skill's SKILL.md and bundled scripts/references paths
skill-lib load temporal-developer

# Attach a short startup disambiguation hint to an opaque/brand-named skill
skill-lib hint last30days "social/reddit/youtube"

# Rename an ambiguously named library skill folder (and its SKILL.md frontmatter name)
skill-lib rename my-opaque-skill postgres-query-optimizer

# Run diagnostics (checks paths, missing SKILL.md, index drift, name collisions, permissions & hooks)
skill-lib doctor
skill-lib doctor --fix

# Rebuild skill-librarian/SKILL.md after manually adding folders to ~/.agent-skills-library/
skill-lib sync
```

---

## Environment Variables & Multi-Harness Support

`skill-lib` automatically detects your active skills directory (`~/.claude/skills` or `~/.agents/skills`, resolving symlinks automatically). You can override paths via environment variables:

| Variable | Default | Purpose |
| :--- | :--- | :--- |
| `SKILL_LIB_ACTIVE_DIR` | `~/.claude/skills` (or `~/.agents/skills`) | Directory where `skill-librarian/SKILL.md` and active skills reside |
| `SKILL_LIB_DIR` | `~/.agent-skills-library` | Offline directory where on-demand skills are stored |

## License

MIT
