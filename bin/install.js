#!/usr/bin/env node

/**
 * shipready installer
 * Detects installed AI coding agents and installs the shipready skill
 * to the correct location for each one.
 *
 * Supports: Claude Code, Cursor, Windsurf, Cline, GitHub Copilot, Codex (AGENTS.md)
 *
 * Usage:
 *   node install.js              — auto-detect and install to all found agents
 *   node install.js --agent cursor  — install to a specific agent only
 *   node install.js --uninstall  — remove shipready from all agents
 *   node install.js --check      — show what's installed, don't change anything
 */

const fs   = require("fs");
const path = require("path");
const os   = require("os");

// ─── Config ──────────────────────────────────────────────────────────────────

const REPO_ROOT   = path.resolve(__dirname, "..");   // one level up from /bin
const VERSION     = "1.0.0";
const SKILL_NAME  = "shipready";

// The consolidated skill content Claude / rule-based agents will read.
// We merge SKILL.md + the generate command into one flat file for agents
// that only support a single rules file (Cursor, Windsurf, Cline, Copilot).
function buildFlatSkill() {
  const parts = [
    safeRead(path.join(REPO_ROOT, "SKILL.md")),
    safeRead(path.join(REPO_ROOT, "commands", "shipready.md")),
    ...["security","database","error-handling","api-design",
        "environment","performance","frontend","devops"]
      .map(d => safeRead(path.join(REPO_ROOT, "dimensions", `${d}.md`))),
    safeRead(path.join(REPO_ROOT, "templates", "nextjs-prisma-postgres.md")),
  ];
  return parts.filter(Boolean).join("\n\n---\n\n");
}

function safeRead(filePath) {
  try { return fs.readFileSync(filePath, "utf8").trim(); }
  catch { return null; }
}

// ─── Agent definitions ───────────────────────────────────────────────────────

const HOME = os.homedir();
const CWD  = process.cwd();

const AGENTS = {
  claudeCode: {
    label:   "Claude Code",
    emoji:   "🤖",
    detect() {
      return (
        fs.existsSync(path.join(HOME, ".claude")) ||
        fs.existsSync(path.join(HOME, ".claude", "settings.json"))
      );
    },
    install() {
      const skillDir = path.join(HOME, ".claude", "skills", SKILL_NAME);
      fs.mkdirSync(skillDir, { recursive: true });

      // Copy the full directory structure so Claude Code gets everything
      copyDir(path.join(REPO_ROOT, "commands"),   path.join(skillDir, "commands"));
      copyDir(path.join(REPO_ROOT, "dimensions"), path.join(skillDir, "dimensions"));
      copyDir(path.join(REPO_ROOT, "templates"),  path.join(skillDir, "templates"));
      copyFile(path.join(REPO_ROOT, "SKILL.md"),  path.join(skillDir, "SKILL.md"));

      // Register in Claude Code settings.json if it exists
      const settingsPath = path.join(HOME, ".claude", "settings.json");
      if (fs.existsSync(settingsPath)) {
        try {
          const settings = JSON.parse(fs.readFileSync(settingsPath, "utf8"));
          settings.skills = settings.skills || [];
          if (!settings.skills.includes(SKILL_NAME)) {
            settings.skills.push(SKILL_NAME);
            fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2));
          }
        } catch {
          // settings.json exists but couldn't parse — leave it alone
        }
      }

      return skillDir;
    },
    uninstall() {
      const skillDir = path.join(HOME, ".claude", "skills", SKILL_NAME);
      removeDir(skillDir);

      const settingsPath = path.join(HOME, ".claude", "settings.json");
      if (fs.existsSync(settingsPath)) {
        try {
          const settings = JSON.parse(fs.readFileSync(settingsPath, "utf8"));
          if (settings.skills) {
            settings.skills = settings.skills.filter(s => s !== SKILL_NAME);
            fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2));
          }
        } catch { /* ignore */ }
      }
    },
    installedAt() {
      return path.join(HOME, ".claude", "skills", SKILL_NAME);
    },
  },

  cursor: {
    label:   "Cursor",
    emoji:   "🖱️",
    detect() {
      return (
        fs.existsSync(path.join(CWD, ".cursor")) ||
        fs.existsSync(path.join(HOME, ".cursor"))
      );
    },
    install() {
      // Cursor supports a rules file per-project or globally
      const globalDir  = path.join(HOME, ".cursor", "rules");
      const projectDir = path.join(CWD, ".cursor", "rules");

      // Install globally; if a project .cursor dir exists, install there too
      const targets = [globalDir];
      if (fs.existsSync(path.join(CWD, ".cursor"))) targets.push(projectDir);

      for (const dir of targets) {
        fs.mkdirSync(dir, { recursive: true });
        fs.writeFileSync(
          path.join(dir, `${SKILL_NAME}.md`),
          buildFlatSkill(),
          "utf8"
        );
      }
      return targets[targets.length - 1];
    },
    uninstall() {
      for (const base of [
        path.join(HOME, ".cursor", "rules"),
        path.join(CWD,  ".cursor", "rules"),
      ]) {
        safeRemove(path.join(base, `${SKILL_NAME}.md`));
      }
    },
    installedAt() {
      return path.join(HOME, ".cursor", "rules", `${SKILL_NAME}.md`);
    },
  },

  windsurf: {
    label:   "Windsurf",
    emoji:   "🌊",
    detect() {
      return (
        fs.existsSync(path.join(CWD, ".windsurf")) ||
        fs.existsSync(path.join(HOME, ".windsurf"))
      );
    },
    install() {
      const globalDir  = path.join(HOME, ".windsurf", "rules");
      const projectDir = path.join(CWD,  ".windsurf", "rules");

      const targets = [globalDir];
      if (fs.existsSync(path.join(CWD, ".windsurf"))) targets.push(projectDir);

      for (const dir of targets) {
        fs.mkdirSync(dir, { recursive: true });
        fs.writeFileSync(
          path.join(dir, `${SKILL_NAME}.md`),
          buildFlatSkill(),
          "utf8"
        );
      }
      return targets[targets.length - 1];
    },
    uninstall() {
      for (const base of [
        path.join(HOME, ".windsurf", "rules"),
        path.join(CWD,  ".windsurf", "rules"),
      ]) {
        safeRemove(path.join(base, `${SKILL_NAME}.md`));
      }
    },
    installedAt() {
      return path.join(HOME, ".windsurf", "rules", `${SKILL_NAME}.md`);
    },
  },

  cline: {
    label:   "Cline",
    emoji:   "⚡",
    detect() {
      return (
        fs.existsSync(path.join(CWD, ".clinerules")) ||
        fs.existsSync(path.join(HOME, ".clinerules"))
      );
    },
    install() {
      // Cline uses a flat .clinerules file — append a section if it already exists
      const targets = [];
      if (fs.existsSync(path.join(CWD, ".clinerules"))) {
        targets.push(path.join(CWD, ".clinerules"));
      }
      // Always install to home as fallback
      targets.push(path.join(HOME, ".clinerules"));

      const content = buildFlatSkill();
      const marker  = `<!-- shipready:start -->`;
      const end     = `<!-- shipready:end -->`;
      const block   = `${marker}\n${content}\n${end}\n`;

      for (const target of targets) {
        if (fs.existsSync(target)) {
          const existing = fs.readFileSync(target, "utf8");
          if (existing.includes(marker)) {
            // Replace existing block
            const replaced = existing.replace(
              new RegExp(`${marker}[\\s\\S]*?${end}`, "g"),
              block.trim()
            );
            fs.writeFileSync(target, replaced, "utf8");
          } else {
            fs.appendFileSync(target, `\n\n${block}`);
          }
        } else {
          fs.writeFileSync(target, block, "utf8");
        }
      }
      return targets[0];
    },
    uninstall() {
      for (const target of [
        path.join(CWD,  ".clinerules"),
        path.join(HOME, ".clinerules"),
      ]) {
        if (!fs.existsSync(target)) continue;
        const content = fs.readFileSync(target, "utf8");
        const cleaned = content.replace(
          /<!-- shipready:start -->[\s\S]*?<!-- shipready:end -->\n?/g,
          ""
        ).trim();
        if (cleaned) {
          fs.writeFileSync(target, cleaned + "\n", "utf8");
        } else {
          fs.unlinkSync(target);
        }
      }
    },
    installedAt() {
      return path.join(HOME, ".clinerules");
    },
  },

  copilot: {
    label:   "GitHub Copilot",
    emoji:   "🐙",
    detect() {
      return fs.existsSync(path.join(CWD, ".github"));
    },
    install() {
      const dir    = path.join(CWD, ".github");
      const target = path.join(dir, "copilot-instructions.md");
      fs.mkdirSync(dir, { recursive: true });

      const content = buildFlatSkill();
      const marker  = `<!-- shipready:start -->`;
      const end     = `<!-- shipready:end -->`;
      const block   = `${marker}\n${content}\n${end}\n`;

      if (fs.existsSync(target)) {
        const existing = fs.readFileSync(target, "utf8");
        if (existing.includes(marker)) {
          fs.writeFileSync(
            target,
            existing.replace(
              new RegExp(`${marker}[\\s\\S]*?${end}`, "g"),
              block.trim()
            ),
            "utf8"
          );
        } else {
          fs.appendFileSync(target, `\n\n${block}`);
        }
      } else {
        fs.writeFileSync(target, block, "utf8");
      }
      return target;
    },
    uninstall() {
      const target = path.join(CWD, ".github", "copilot-instructions.md");
      if (!fs.existsSync(target)) return;
      const content = fs.readFileSync(target, "utf8");
      const cleaned = content.replace(
        /<!-- shipready:start -->[\s\S]*?<!-- shipready:end -->\n?/g,
        ""
      ).trim();
      if (cleaned) {
        fs.writeFileSync(target, cleaned + "\n", "utf8");
      } else {
        fs.unlinkSync(target);
      }
    },
    installedAt() {
      return path.join(CWD, ".github", "copilot-instructions.md");
    },
  },

  codex: {
    label:   "Codex / OpenAI",
    emoji:   "🧠",
    detect() {
      return fs.existsSync(path.join(CWD, "AGENTS.md"));
    },
    install() {
      const target  = path.join(CWD, "AGENTS.md");
      const content = buildFlatSkill();
      const marker  = `<!-- shipready:start -->`;
      const end     = `<!-- shipready:end -->`;
      const block   = `${marker}\n${content}\n${end}\n`;

      if (fs.existsSync(target)) {
        const existing = fs.readFileSync(target, "utf8");
        if (existing.includes(marker)) {
          fs.writeFileSync(
            target,
            existing.replace(
              new RegExp(`${marker}[\\s\\S]*?${end}`, "g"),
              block.trim()
            ),
            "utf8"
          );
        } else {
          fs.appendFileSync(target, `\n\n${block}`);
        }
      } else {
        fs.writeFileSync(target, block, "utf8");
      }
      return target;
    },
    uninstall() {
      const target = path.join(CWD, "AGENTS.md");
      if (!fs.existsSync(target)) return;
      const content = fs.readFileSync(target, "utf8");
      const cleaned = content.replace(
        /<!-- shipready:start -->[\s\S]*?<!-- shipready:end -->\n?/g,
        ""
      ).trim();
      if (cleaned) {
        fs.writeFileSync(target, cleaned + "\n", "utf8");
      } else {
        fs.unlinkSync(target);
      }
    },
    installedAt() {
      return path.join(CWD, "AGENTS.md");
    },
  },
};

// ─── File helpers ─────────────────────────────────────────────────────────────

function copyFile(src, dest) {
  if (!fs.existsSync(src)) return;
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.copyFileSync(src, dest);
}

function copyDir(src, dest) {
  if (!fs.existsSync(src)) return;
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const srcPath  = path.join(src,  entry.name);
    const destPath = path.join(dest, entry.name);
    if (entry.isDirectory()) {
      copyDir(srcPath, destPath);
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

function removeDir(dirPath) {
  if (!fs.existsSync(dirPath)) return;
  fs.rmSync(dirPath, { recursive: true, force: true });
}

function safeRemove(filePath) {
  try { if (fs.existsSync(filePath)) fs.unlinkSync(filePath); }
  catch { /* ignore */ }
}

// ─── CLI helpers ──────────────────────────────────────────────────────────────

const RESET  = "\x1b[0m";
const BOLD   = "\x1b[1m";
const GREEN  = "\x1b[32m";
const YELLOW = "\x1b[33m";
const RED    = "\x1b[31m";
const CYAN   = "\x1b[36m";
const DIM    = "\x1b[2m";

function log(msg)         { console.log(msg); }
function success(msg)     { console.log(`${GREEN}✅ ${msg}${RESET}`); }
function warn(msg)        { console.log(`${YELLOW}⚠️  ${msg}${RESET}`); }
function error(msg)       { console.error(`${RED}❌ ${msg}${RESET}`); }
function info(msg)        { console.log(`${CYAN}   ${msg}${RESET}`); }
function dim(msg)         { console.log(`${DIM}   ${msg}${RESET}`); }
function header(msg)      { console.log(`\n${BOLD}${msg}${RESET}\n`); }
function separator()      { console.log(`${DIM}${"─".repeat(50)}${RESET}`); }

function printBanner() {
  console.log(`
${BOLD}${CYAN}🚢 shipready installer v${VERSION}${RESET}
${DIM}Generate production-grade apps from one sentence${RESET}
`);
}

// ─── Modes ────────────────────────────────────────────────────────────────────

function runInstall(targetAgent) {
  const found = [];

  for (const [key, agent] of Object.entries(AGENTS)) {
    if (targetAgent && key !== targetAgent) continue;

    if (!targetAgent && !agent.detect()) continue;

    log(`${agent.emoji} ${BOLD}${agent.label}${RESET} detected...`);
    try {
      const installedPath = agent.install();
      success(`Installed to ${DIM}${installedPath}${RESET}`);
      found.push(agent.label);
    } catch (err) {
      error(`Failed to install for ${agent.label}: ${err.message}`);
    }
    separator();
  }

  if (found.length === 0) {
    if (targetAgent) {
      error(`Agent "${targetAgent}" not found or not installed on this machine.`);
      log(`\nAvailable agents: ${Object.keys(AGENTS).join(", ")}`);
    } else {
      warn("No supported AI coding agents detected.");
      log("\nSupported agents: Claude Code, Cursor, Windsurf, Cline, GitHub Copilot, Codex");
      log(`\nTo install manually for a specific agent:`);
      log(`  node install.js --agent claudeCode`);
      log(`  node install.js --agent cursor`);
    }
    return;
  }

  log(`\n${BOLD}${GREEN}🚢 shipready installed for: ${found.join(", ")}${RESET}`);
  log(`\n${BOLD}Try it:${RESET}`);
  info(`/shipready "your app description"`);
  info(`/shipready "restaurant booking app with admin panel"`);
  info(`/shipready "SaaS waitlist with email capture"`);
  log(`\n${DIM}Docs: https://github.com/YOURUSERNAME/shipready${RESET}\n`);
}

function runUninstall(targetAgent) {
  const removed = [];

  for (const [key, agent] of Object.entries(AGENTS)) {
    if (targetAgent && key !== targetAgent) continue;

    const installedPath = agent.installedAt();
    const exists =
      fs.existsSync(installedPath) ||
      (key === "claudeCode" && fs.existsSync(path.join(HOME, ".claude", "skills", SKILL_NAME)));

    if (!exists && !targetAgent) continue;

    log(`${agent.emoji} ${BOLD}${agent.label}${RESET} — removing...`);
    try {
      agent.uninstall();
      success(`Removed from ${DIM}${installedPath}${RESET}`);
      removed.push(agent.label);
    } catch (err) {
      error(`Failed to uninstall from ${agent.label}: ${err.message}`);
    }
    separator();
  }

  if (removed.length === 0) {
    warn("shipready was not found on this machine.");
  } else {
    log(`\n${BOLD}${GREEN}🗑️  shipready removed from: ${removed.join(", ")}${RESET}\n`);
  }
}

function runCheck() {
  header("shipready installation status");

  let anyFound = false;

  for (const [key, agent] of Object.entries(AGENTS)) {
    const agentDetected = agent.detect();
    const installedPath = agent.installedAt();
    const isInstalled   =
      fs.existsSync(installedPath) ||
      (key === "claudeCode" && fs.existsSync(path.join(HOME, ".claude", "skills", SKILL_NAME)));

    const agentStatus   = agentDetected ? `${GREEN}found${RESET}` : `${DIM}not found${RESET}`;
    const skillStatus   = isInstalled
      ? `${GREEN}✓ installed${RESET}`
      : agentDetected
        ? `${YELLOW}✗ not installed${RESET}`
        : `${DIM}—${RESET}`;

    log(`${agent.emoji}  ${BOLD}${agent.label.padEnd(20)}${RESET} agent: ${agentStatus}   skill: ${skillStatus}`);
    if (isInstalled) {
      dim(installedPath);
      anyFound = true;
    }
  }

  log("");

  if (!anyFound) {
    warn("shipready is not installed anywhere.");
    log(`Run ${CYAN}node install.js${RESET} to install.`);
  } else {
    success("shipready is active. Try: /shipready your app description");
  }
  log("");
}

// ─── Entry point ─────────────────────────────────────────────────────────────

function main() {
  printBanner();

  const args        = process.argv.slice(2);
  const uninstall   = args.includes("--uninstall") || args.includes("-u");
  const check       = args.includes("--check")     || args.includes("-c");
  const agentFlag   = args.indexOf("--agent");
  const targetAgent = agentFlag !== -1 ? args[agentFlag + 1] : null;

  // Validate --agent value if provided
  if (targetAgent && !AGENTS[targetAgent]) {
    error(`Unknown agent: "${targetAgent}"`);
    log(`\nValid agent keys: ${Object.keys(AGENTS).join(", ")}`);
    process.exit(1);
  }

  if (check) {
    runCheck();
  } else if (uninstall) {
    header(targetAgent ? `Uninstalling from ${AGENTS[targetAgent].label}...` : "Uninstalling from all agents...");
    runUninstall(targetAgent);
  } else {
    header(targetAgent ? `Installing to ${AGENTS[targetAgent].label}...` : "Detecting AI coding agents...");
    runInstall(targetAgent);
  }
}

main();