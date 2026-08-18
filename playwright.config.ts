import path from "path";
import { defineConfig } from "@playwright/test";

const DEFAULT_HOST = process.env.APP_HOST || "127.0.0.1";
const DEFAULT_PORT = process.env.APP_SERVER_PORT || process.env.PORT || "3000";
const baseURL =
  process.env.PLAYWRIGHT_BASE_URL || `http://${DEFAULT_HOST}:${DEFAULT_PORT}`;
const configuredWorkers = Number.parseInt(process.env.PLAYWRIGHT_WORKERS || "1", 10);
const workers = Number.isFinite(configuredWorkers) && configuredWorkers > 0
  ? Math.min(configuredWorkers, 4)
  : 1;

export default defineConfig({
  testDir: "./playwright",
  outputDir: path.resolve("tmp", "playwright"),
  fullyParallel: false,
  forbidOnly: Boolean(process.env.CI),
  retries: process.env.CI ? 1 : 0,
  workers,
  reporter: process.env.CI ? "github" : [["list"]],
  use: {
    baseURL,
    trace: "on-first-retry",
    screenshot: "only-on-failure",
    video: "on-first-retry",
  },
});
