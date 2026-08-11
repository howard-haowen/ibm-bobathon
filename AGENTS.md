# w02 Workshop — Agent Operations Guide

Operational specifications for AI agents working on the w02 workshop branch.

## Branch Identity

- **Branch**: `workshop/w02`
- **Scope**: Workshop w02 artifacts and configuration
- **Deployment**: GitHub Pages at `https://howard-haowen.github.io/ibm-bobathon/workshops/w02/`

## Tracked Files on This Branch

```
workshop/w02/
├── README.md                       # Human guide (Traditional Chinese)
├── AGENTS.md                       # This file
├── DESIGN.md                       # IBM Carbon Design System specification
├── .gitignore                      # Git ignore rules
├── skills-lock.json                # Bob skill dependency lock
├── .bob/
│   ├── mcp.json                   # MCP server configuration
│   └── skills/find-skills/SKILL.md # Skill discovery tool
└── artifacts/                      # Teaching materials (primary content)
    ├── 01-ibm-bob-basic-usage.html
    ├── 02-cobol-documentation.html
    ├── 03-wasdb2mq-ansible-ops.html
    └── index.html
```

**Total tracked files**: 11 (see output of `git ls-files` for canonical list)

## File Responsibilities

### Teaching Materials (Primary)

| File | Purpose | Status |
|------|---------|--------|
| `artifacts/01-ibm-bob-basic-usage.html` | IBM Bob fundamentals | Active |
| `artifacts/02-cobol-documentation.html` | COBOL program documentation | Active |
| `artifacts/03-wasdb2mq-ansible-ops.html` | Operations & automation guide | Active |
| `artifacts/index.html` | Card-based landing page | Auto-generated |

### Configuration & Standards

| File | Purpose | Editable | Notes |
|------|---------|----------|-------|
| `DESIGN.md` | Design System reference | Read-only | Complete specification |
| `.gitignore` | Git exclusion rules | No | System file |
| `skills-lock.json` | Dependency lock | No | Managed by Bob CLI |
| `.bob/mcp.json` | MCP configuration | Yes | Only if needed |
| `.bob/skills/find-skills/SKILL.md` | Skill definition | Yes | If modifying tooling |
| `README.md` | Human documentation | Yes | Keep synchronized |
| `AGENTS.md` | Agent documentation | Yes | This file |

## Design System Constraints

All HTML artifacts **must** comply with `DESIGN.md` (IBM Carbon Design System). Non-compliance blocks deployment.

### Mandatory Constraints

- **Color Palette**: Only use colors defined in `DESIGN.md`
  - Primary: IBM Blue `#0f62fe` (links, CTAs, focus underlines only)
  - Text: Charcoal `#161616` (headlines, body)
  - Surfaces: White `#ffffff` + light gray `#f4f4f4`
  - Semantic: Green `#24a148`, Yellow `#f1c21b`, Red `#da1e28`

- **Typography**: IBM Plex Sans only
  - Display sizes (42–76px): weight 300 (light)
  - Body (12–18px): weight 400
  - Emphasis: weight 600 (rare)
  - All body text: `letter-spacing: 0.16px`

- **Geometry**: Square corners everywhere
  - `border-radius: 0px` (no exceptions)
  - No pill-shaped buttons, no soft edges

- **Spacing**: 4px base grid
  - Tokens: 4, 8, 12, 16, 24, 32, 48, 96 (px only)
  - No arbitrary spacing values

- **Depth & Effects**:
  - No drop shadows
  - No gradients (except optional soft-blue hero backdrop)
  - No atmospheric overlays
  - Elevation via surface change + hairlines only

### Validation Rules

Before commit:
1. ✅ Parse HTML — valid DOM structure
2. ✅ Scan CSS — only colors from `DESIGN.md`
3. ✅ Check `border-radius` — must be `0px` everywhere
4. ✅ Verify fonts — IBM Plex Sans only
5. ✅ Test responsive widths — 320, 672, 1056, 1312, 1584 px
6. ✅ Scan for external resources — no `<script>`, `<iframe>`, external CSS/JS

## Git Operations & Commit Rules

### Branch Context

```
main (publish-only aggregate)
  ↑
  └─── cherry-pick from
  
workshop/w02 (your workspace)
  ├─── push to origin
  └─── generates → artifacts published at GitHub Pages
```

### Commit Message Format

```
<type>(<scope>): <subject>

type:   feat | fix | docs | style | refactor | test | chore
scope:  w02 (always)
subject: imperative, lowercase, no period, max 50 chars
```

**Examples**:
```
feat(w02): add ansible automation guide to artifacts
fix(w02): correct Carbon Blue color in header
docs(w02): update README with deployment steps
chore(w02): regenerate index.html card list
```

### Safe Operations

✅ **Do**:
- `git add artifacts/` (modify HTML)
- `git add AGENTS.md` (update agent docs)
- `git add README.md` (update human docs)
- `git add .bob/mcp.json` (if MCP config changes)
- `git commit -m "type(w02): message"`
- `git push origin workshop/w02`

❌ **Don't**:
- Push to `main` directly (cherry-pick only)
- Force-push (`git push -f`)
- Delete tracked files without reason
- Modify `DESIGN.md` (reference only)
- Modify `skills-lock.json` (managed by Bob)

### Deployment Flow

```bash
# 1. Local development
git checkout workshop/w02
# ... edit artifacts/XX.html ...
git add artifacts/
git commit -m "feat(w02): add new module"
git push origin workshop/w02
# [visible at staging / test environment]

# 2. Publish to GitHub Pages (from main)
git checkout main
git fetch origin
git checkout workshop/w02 -- artifacts/
git add .
git commit -m "feat(w02): publish new module"
git push origin main
# [GitHub Actions runs, deploys in 1–2 min to GitHub Pages]
```

## File Integrity Rules

### HTML Artifact Rules

- **Self-contained**: All CSS inline (`<style>` tag), no external links
- **Images**: Data URIs only (embedded as base64), no external src
- **Security**: No `<script>`, `<iframe>`, `<form>`, event handlers
- **Accessibility**: Semantic HTML5, proper heading hierarchy
- **Size**: Keep < 5MB per file (optimize images)
- **Encoding**: UTF-8, no BOM

### Configuration File Rules

- **`.bob/mcp.json`**: Only edit if MCP server setup changes; validate JSON syntax
- **`skills-lock.json`**: Read-only; do not hand-edit (managed by `bob` CLI)
- **`.gitignore`**: Do not modify; system-managed
- **`README.md` / `AGENTS.md`**: Keep synchronized when constraints/workflows change

## Operational Patterns

### Pattern: Add New Training Module

```bash
git checkout workshop/w02

# Create new HTML file (validate against DESIGN.md)
cat > artifacts/04-new-topic.html << 'EOF'
<!DOCTYPE html>
<html lang="zh-TW">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>New Topic</title>
  <style>
    /* Inline CSS only, Carbon Design System compliant */
    body { font-family: "IBM Plex Sans", sans-serif; color: #161616; }
    h1 { font-size: 42px; font-weight: 300; letter-spacing: -0.5px; }
    a { color: #0f62fe; text-decoration: none; }
    button { background: #0f62fe; color: #ffffff; border: none; padding: 12px 16px; border-radius: 0px; }
  </style>
</head>
<body>
  <h1>New Topic Title</h1>
  <p>Content here...</p>
</body>
</html>
EOF

git add artifacts/04-new-topic.html
git commit -m "feat(w02): add new training module on specific topic"
git push origin workshop/w02
```

### Pattern: Fix Design Violation

```bash
git checkout workshop/w02

# Identify violation (e.g., wrong color, rounded corners)
# Edit file to comply with DESIGN.md

git add artifacts/XX-module.html
git commit -m "fix(w02): correct Carbon Design System compliance"
git push origin workshop/w02
```

### Pattern: Update Documentation

```bash
git checkout workshop/w02

# Edit README.md or AGENTS.md
# Keep in sync with actual branch contents

git add README.md AGENTS.md
git commit -m "docs(w02): update operational documentation"
git push origin workshop/w02
```

## Validation Checklist

Before committing HTML artifacts:

- [ ] Valid HTML5 syntax
- [ ] No external `<script>` tags
- [ ] No `<iframe>`, `<form>`, or form elements
- [ ] All colors match `DESIGN.md` palette
- [ ] `border-radius: 0px` everywhere (test CSS)
- [ ] Font: IBM Plex Sans only
- [ ] Responsive design tested at: 320, 672, 1056, 1312, 1584 px
- [ ] Images: inline data URI only (no external src)
- [ ] CSS: inline `<style>` tag only
- [ ] File size < 5MB
- [ ] UTF-8 encoding, no BOM
- [ ] Semantic HTML (proper heading hierarchy, alt text)

## Troubleshooting

### Issue: Push rejected (branch out of date)

```bash
git fetch origin
git rebase origin/workshop/w02
git push origin workshop/w02
```

### Issue: Design compliance check fails

1. Compare color values to `DESIGN.md`
2. Verify `border-radius` values (should be 0px)
3. Check font-family declarations
4. Test responsive widths
5. Rerun compliance scan

### Issue: HTML validation error

1. Validate HTML5 syntax online or with `htmllint`
2. Check for missing closing tags
3. Ensure all attributes are quoted
4. Verify character encoding (UTF-8)

## Success Criteria

A successful w02 workshop branch state:

1. ✅ All tracked files present and valid
2. ✅ All HTML artifacts comply with `DESIGN.md`
3. ✅ No design system violations (color, corners, fonts, spacing)
4. ✅ All commits follow conventional commit format
5. ✅ README.md and AGENTS.md kept in sync
6. ✅ Ready to cherry-pick to `main` for publication

---

**Branch**: `workshop/w02`
**Status**: Active
**Scope**: w02 workshop artifacts and configuration
**Last Updated**: 2024-12
