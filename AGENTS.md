# Repository Agent Guidelines: The Biscuit Plug

## Overview
This repository contains the web app for **The Biscuit Plug** (South Africa, Port Elizabeth / Gqeberha).
Live deployment target: GitHub Pages and Node/Express container.

## Architecture
- **Frontend**: React 19, Vite, Tailwind CSS v4, Lucide icons, Motion
- **Backend / API**: Express (`server.ts`), Supabase client (`server/supabase.ts`), local fallback DB (`server/db.ts`)
- **Direct Client Supabase**: `src/lib/supabase.ts` for GitHub Pages static execution or direct frontend queries
- **Data Stores**:
  - Products, orders, memes, bakery settings synced with Supabase
  - Local JSON database fallback in `/data/biscuit_db.json` when credentials are unset

## Automation & GitHub Actions
- `deploy.yml`: Vite build and deployment to GitHub Pages (`gh-pages`)
- `static.yml`: Static site deployment fallback
- `.github/dependabot.yml`: Automated dependency updates for npm packages and GitHub Actions
