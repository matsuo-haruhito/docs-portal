// @ts-check
"use strict";

const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright");

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

const APP_HOST = process.env.APP_HOST || "localhost";
const APP_SERVER_PORT = process.env.APP_SERVER_PORT || "3000";
const BASE_URL = `http://${APP_HOST}:${APP_SERVER_PORT}`;
const SCREENSHOT_DIR = process.env.SCREENSHOT_DIR || "tmp/screenshots";
const SCREENSHOT_EMAIL = process.env.SCREENSHOT_EMAIL || "admin@example.com";
const SCREENSHOT_WIDTH = parseInt(process.env.SCREENSHOT_WIDTH || "1440", 10);
const SCREENSHOT_HEIGHT = parseInt(process.env.SCREENSHOT_HEIGHT || "1600", 10);
const ROUTES_FILE = process.env.ROUTES_FILE || "config/routes.rb";
const TIMEOUT = 120000;

// 親リソースのIDなしではアクセスできないトップレベル定義（ネストルート側で撮影する）
// これらは公開側で projects/:code 配下にネストされているため、トップレベルでは 404 になる
const SKIP_TOPLEVEL_RESOURCES = new Set([
  "document_sets",
  "document_catalogs",
  "document_uploads",
  "document_review_comments",
  "document_versions",
  "document_files",
  "document_zips",
]);

// new アクションがパラメータ必須のため撮影対象外にするリソース
const SKIP_NEW_ACTION_RESOURCES = new Set([
  "consents",
]);

// query parameter付きの状態名captureを正本にし、default indexの重複撮影を避ける
const SKIP_GENERIC_INDEX_CONTROLLERS = new Set([
  "admin/document_permissions",
  "document_bookmarks",
]);

// resources/resourceの簡易探索では検出できないcustom route・状態別画面
const CUSTOM_SCREENSHOT_TARGETS = [
  { path: "/documents", name: "accessible_documents_index" },
  { path: "/admin/diagnostics", name: "admin_diagnostics_index" },
  {
    path: "/admin/document_permissions?view=assignments",
    name: "admin_document_permissions_assignments",
  },
  {
    path: "/admin/document_permissions?view=overview",
    name: "admin_document_permissions_overview",
  },
  {
    path: "/document_bookmarks?view=favorite",
    name: "document_bookmarks_favorite",
  },
  {
    path: "/document_bookmarks?view=read_later",
    name: "document_bookmarks_read_later",
  },
  {
    path: "/document_bookmarks?view=recent",
    name: "document_bookmarks_recent",
  },
];

// ---------------------------------------------------------------------------
// Route Discovery
// ---------------------------------------------------------------------------

/**
 * @typedef {{
 *   name: string,
 *   controller: string,
 *   path: string,
 *   actions: string[],
 *   param: string,
 *   namespace: string,
 *   singular: boolean,
 *   nested?: Route[]
 * }} Route
 */

/**
 * Parse routes.rb and discover resource routes.
 * Uses indentation-based tracking to correctly handle nested do...end blocks.
 * @param {string} routesFile
 * @returns {Route[]}
 */
function discoverRoutes(routesFile) {
  const content = fs.readFileSync(routesFile, "utf-8");
  const lines = content.split("\n");

  /** @type {Route[]} */
  const routes = [];
  const allActions = ["index", "show", "new", "edit", "create", "update", "destroy"];

  // Use indentation to track namespace scope and resource nesting
  // namespaceStack entries: { name, indent }
  // nestingDepth tracks how deep we are inside resource do...end blocks
  const namespaceStack = [];
  let nestingDepth = 0;
  const nestingIndents = [];

  for (let i = 0; i < lines.length; i++) {
    const raw = lines[i];
    const indent = raw.length - raw.trimStart().length;
    const line = raw.trim();

    // Skip empty lines and comments
    if (!line || line.startsWith("#")) continue;

    // Track namespace open
    const nsMatch = line.match(/^namespace\s+:(\w+)\s+do/);
    if (nsMatch) {
      namespaceStack.push({ name: nsMatch[1], indent });
      continue;
    }

    // Track "end" — close namespace or resource nesting
    if (line === "end") {
      if (namespaceStack.length > 0) {
        const top = namespaceStack[namespaceStack.length - 1];
        if (indent === top.indent) {
          namespaceStack.pop();
          continue;
        }
      }
      if (nestingDepth > 0 && nestingIndents.length > 0) {
        const topNest = nestingIndents[nestingIndents.length - 1];
        if (indent === topNest) {
          nestingDepth--;
          nestingIndents.pop();
        }
      }
      continue;
    }

    // Match resources / resource
    const resourceMatch = line.match(/^(resources?)\s+:(\w+)(?:,\s*(.+?))?(?:\s+do)?$/);
    if (!resourceMatch) {
      continue;
    }

    const hasDoBlock = line.endsWith(" do");
    const isSingular = resourceMatch[1] === "resource";
    const resourceName = resourceMatch[2];
    const options = resourceMatch[3] || "";

    // Skip resources nested inside other resources (they need parent ID)
    if (nestingDepth > 0) {
      if (hasDoBlock) {
        nestingDepth++;
        nestingIndents.push(indent);
      }
      continue;
    }

    // Parse actions
    let actions = isSingular
      ? ["show", "new", "edit", "create", "update", "destroy"]
      : [...allActions];

    const onlyMatch = options.match(/only:\s*%i\[([^\]]+)\]/);
    const exceptMatch = options.match(/except:\s*%i\[([^\]]+)\]/);
    const onlyArrayMatch = options.match(/only:\s*\[([^\]]+)\]/);
    const exceptArrayMatch = options.match(/except:\s*\[([^\]]+)\]/);

    if (onlyMatch) {
      actions = onlyMatch[1].split(/\s+/);
    } else if (exceptMatch) {
      const excluded = exceptMatch[1].split(/\s+/);
      actions = actions.filter((a) => !excluded.includes(a));
    } else if (onlyArrayMatch) {
      actions = onlyArrayMatch[1].split(/,\s*/).map((s) => s.replace(/:/g, "").trim());
    } else if (exceptArrayMatch) {
      const excluded = exceptArrayMatch[1].split(/,\s*/).map((s) => s.replace(/:/g, "").trim());
      actions = actions.filter((a) => !excluded.includes(a));
    }

    // Parse param
    let param = "id";
    const paramMatch = options.match(/param:\s*:(\w+)/);
    if (paramMatch) {
      param = paramMatch[1];
    }

    // Build path
    const namespace = namespaceStack.map((ns) => ns.name).join("/");
    const basePath = namespace ? `/${namespace}/${resourceName}` : `/${resourceName}`;
    const controller = namespace ? `${namespace}/${resourceName}` : resourceName;

    routes.push({
      name: resourceName,
      controller,
      path: basePath,
      actions: actions.filter((a) => ["index", "show", "new", "edit"].includes(a)),
      param,
      namespace,
      singular: isSingular,
    });

    // Track resource do...end block nesting
    if (hasDoBlock) {
      nestingDepth++;
      nestingIndents.push(indent);
    }
  }

  return routes;
}

/**
 * Annotate routes with view template existence.
 * @param {Route[]} routes
 * @returns {Route[]}
 */
function annotateRoutesWithViews(routes) {
  return routes.map((route) => {
    const viewActions = route.actions.filter((action) => {
      const controllerPath = route.controller;
      const slimPath = path.join("app/views", controllerPath, `${action}.html.slim`);
      const erbPath = path.join("app/views", controllerPath, `${action}.html.erb`);
      return fs.existsSync(slimPath) || fs.existsSync(erbPath);
    });
    return { ...route, actions: viewActions };
  });
}

// ---------------------------------------------------------------------------
// Screenshot Helpers
// ---------------------------------------------------------------------------

/**
 * @param {import('playwright').Page} page
 * @param {string} url
 * @param {string} screenshotName
 * @returns {Promise<boolean>}
 */
async function navigateAndCapture(page, url, screenshotName) {
  const response = await page.goto(url, { waitUntil: "networkidle", timeout: TIMEOUT });
  if (!response) {
    throw new Error(`${screenshotName}: no HTTP response from ${url}`);
  }
  if (response.status() >= 400) {
    throw new Error(`${screenshotName}: HTTP ${response.status()} from ${url}`);
  }
  await page.waitForTimeout(500);

  // PNG スクリーンショット
  const pngPath = path.join(SCREENSHOT_DIR, `${screenshotName}.png`);
  await page.screenshot({ path: pngPath, fullPage: true });

  // HTML スナップショット
  const htmlPath = path.join(SCREENSHOT_DIR, `${screenshotName}.html`);
  const htmlContent = await page.content();
  fs.writeFileSync(htmlPath, htmlContent, "utf-8");

  console.log(`  ✓ ${screenshotName} (.png + .html)`);
  return true;
}

/**
 * Login via capture_login endpoint.
 * @param {import('playwright').Page} page
 */
async function login(page) {
  const loginUrl = `${BASE_URL}/capture_login?email=${encodeURIComponent(SCREENSHOT_EMAIL)}&redirect=/admin`;
  console.log(`Logging in via ${loginUrl}`);
  const response = await page.goto(loginUrl, { waitUntil: "networkidle", timeout: TIMEOUT });
  if (!response || response.status() >= 400) {
    throw new Error(`Login failed with status ${response ? response.status() : "no response"}`);
  }
  console.log("  ✓ Login successful");
}

/**
 * Capture index page.
 * @param {import('playwright').Page} page
 * @param {Route} route
 * @returns {Promise<boolean>}
 */
async function captureIndex(page, route) {
  const url = `${BASE_URL}${route.path}`;
  const name = route.controller.replace(/\//g, "_") + "_index";
  return navigateAndCapture(page, url, name);
}

/**
 * Capture custom routes and query-parameter variants that resource discovery cannot represent.
 * @param {import('playwright').Page} page
 * @returns {Promise<void>}
 */
async function captureCustomTargets(page) {
  console.log(`Capturing custom routes (${CUSTOM_SCREENSHOT_TARGETS.length})...`);
  for (const target of CUSTOM_SCREENSHOT_TARGETS) {
    await navigateAndCapture(page, `${BASE_URL}${target.path}`, target.name);
  }
  console.log("");
}

/**
 * Capture new page.
 * @param {import('playwright').Page} page
 * @param {Route} route
 * @returns {Promise<boolean>}
 */
async function captureNew(page, route) {
  if (SKIP_NEW_ACTION_RESOURCES.has(route.name)) {
    console.log(`  — ${route.name} new skipped (requires parameters)`);
    return true;
  }
  const url = `${BASE_URL}${route.path}/new`;
  const name = route.controller.replace(/\//g, "_") + "_new";
  return navigateAndCapture(page, url, name);
}

/**
 * Capture detail (show) and edit pages by finding first link in index table.
 * @param {import('playwright').Page} page
 * @param {Route} route
 * @returns {Promise<void>}
 */
async function captureDetailAndEdit(page, route) {
  const prefix = route.controller.replace(/\//g, "_");

  // First navigate to index to find a link
  const indexUrl = `${BASE_URL}${route.path}`;
  try {
    const response = await page.goto(indexUrl, { waitUntil: "networkidle", timeout: TIMEOUT });
    if (!response || response.status() >= 400) return;
  } catch {
    return;
  }

  // Find first detail link in main content table
  const detailLink = await page.$(`main table tbody a[href*="${route.path}/"], main a[href*="${route.path}/"]`);
  if (!detailLink) {
    // Try direct approach: find any link that looks like a show link
    const anyLink = await page.$(`a[href*="${route.path}/"]`);
    if (!anyLink) return;

    const href = await anyLink.getAttribute("href");
    if (!href) return;

    // Show page
    if (route.actions.includes("show")) {
      await navigateAndCapture(page, `${BASE_URL}${href}`, `${prefix}_show`);
    }

    // Edit page
    if (route.actions.includes("edit")) {
      await navigateAndCapture(page, `${BASE_URL}${href}/edit`, `${prefix}_edit`);
    }
    return;
  }

  const href = await detailLink.getAttribute("href");
  if (!href) return;

  // Show page
  if (route.actions.includes("show")) {
    await navigateAndCapture(page, `${BASE_URL}${href}`, `${prefix}_show`);
  }

  // Edit page
  if (route.actions.includes("edit")) {
    // Try to find edit link or construct edit URL
    const editHref = href.endsWith("/edit") ? href : `${href}/edit`;
    await navigateAndCapture(page, `${BASE_URL}${editHref}`, `${prefix}_edit`);
  }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  console.log("=== docs-portal Screenshot Capture ===");
  console.log(`Base URL: ${BASE_URL}`);
  console.log(`Output: ${SCREENSHOT_DIR}`);
  console.log(`Routes: ${ROUTES_FILE}`);
  console.log("");

  // Ensure output directory
  fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });

  // Discover and annotate routes
  console.log("Discovering routes...");
  let routes = discoverRoutes(ROUTES_FILE);
  routes = annotateRoutesWithViews(routes);
  const routesWithViews = routes.filter((r) => r.actions.length > 0);
  console.log(`  Found ${routes.length} resources, ${routesWithViews.length} with view templates`);
  console.log("");

  // Launch browser
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: SCREENSHOT_WIDTH, height: SCREENSHOT_HEIGHT },
    ignoreHTTPSErrors: true,
  });
  const page = await context.newPage();
  page.setDefaultTimeout(TIMEOUT);

  try {
    // Login
    await login(page);
    console.log("");

    // Capture admin dashboard
    console.log("Capturing admin dashboard...");
    await navigateAndCapture(page, `${BASE_URL}/admin`, "admin_dashboard");
    console.log("");

    // Capture custom routes and tab states
    await captureCustomTargets(page);

    // Capture admin routes
    const adminRoutes = routesWithViews.filter((r) => r.namespace === "admin");
    if (adminRoutes.length > 0) {
      console.log(`Capturing admin routes (${adminRoutes.length})...`);
      for (const route of adminRoutes) {
        console.log(`  [${route.name}]`);
        if (route.actions.includes("index")) {
          if (SKIP_GENERIC_INDEX_CONTROLLERS.has(route.controller)) {
            console.log(`  — ${route.controller} index skipped (covered by named variants)`);
          } else {
            await captureIndex(page, route);
          }
        }
        if (route.actions.includes("new")) {
          await captureNew(page, route);
        }
        if (route.actions.includes("show") || route.actions.includes("edit")) {
          await captureDetailAndEdit(page, route);
        }
      }
      console.log("");
    }

    // Capture public routes
    const publicRoutes = routesWithViews.filter((r) => !r.namespace && !SKIP_TOPLEVEL_RESOURCES.has(r.name));
    if (publicRoutes.length > 0) {
      console.log(`Capturing public routes (${publicRoutes.length})...`);

      // Dashboard first
      await navigateAndCapture(page, `${BASE_URL}/dashboard`, "dashboard");

      for (const route of publicRoutes) {
        console.log(`  [${route.name}]`);
        if (route.actions.includes("index")) {
          if (SKIP_GENERIC_INDEX_CONTROLLERS.has(route.controller)) {
            console.log(`  — ${route.controller} index skipped (covered by named variants)`);
          } else {
            await captureIndex(page, route);
          }
        }
        if (route.actions.includes("new")) {
          await captureNew(page, route);
        }
        if (route.actions.includes("show") || route.actions.includes("edit")) {
          await captureDetailAndEdit(page, route);
        }
      }
      console.log("");
    }

    // Root page
    console.log("Capturing root page...");
    await navigateAndCapture(page, `${BASE_URL}/`, "root");

    console.log("");
    console.log("=== Screenshot capture complete ===");
  } finally {
    await context.close();
    await browser.close();
  }
}

main().catch((err) => {
  console.error("Screenshot capture failed:", err.message);
  process.exit(1);
});
