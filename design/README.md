# Design Profiles Guide

This directory stores imported design profiles from `VoltAgent/awesome-design-md`.

## Current Strategy

1. Use Batch 1 as the default for day-to-day UI development.
2. Switch to Batch 2 only when current UI direction is unsatisfactory and needs major redesign.
3. Keep imported profiles as a local design library; only project-root `DESIGN.md` controls active style.

## Batch 1 (Imported)

- `vercel`
- `linear.app`
- `stripe`
- `notion`
- `figma`
- `supabase`
- `shopify`
- `webflow`
- `cursor`
- `raycast`
- `intercom`
- `airtable`
- `framer`
- `apple`
- `spotify`
- `uber`
- `claude`
- `posthog`

## Batch 2 (Suggested Next)

- `mongodb`
- `sentry`
- `resend`
- `zapier`
- `wise`
- `x.ai`
- `nvidia`
- `meta`
- `superhuman`
- `mintlify`

## Activate A Profile

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Import-DesignProfile.ps1 -Profile <profile> -SetProjectDesign -Force
```

