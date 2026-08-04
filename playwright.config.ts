import path from "path";
import { defineConfig } from "@playwright/test";

const DEFAULT_HOST = process.env.APP_HOST || "127.0.0.1";
const DEFAULT_PORT = process.env.APP_SERVER_PORT || process.env.PORT || "3000";
const baseURL =
  process.env.PLAYWRIGHT_BASE_URL || `http://${DEFAULT_HOST}:${DEFAULT_PORT}`;

export default defineConfig({
  testDir: "./playwright",
  outputDir: path.resolve("tmp", "playwright"),
  fullyParallel: false,
  forbidOnly: Boolean(process.env.CI),
  retries: process.env.CI ? 1 : 0,
  workers: 1,
  reporter: process.env.CI ? "github" : [["list"]],
  use: {
    baseURL,
    trace: "on-first-retry",
    screenshot: "only-on-failure",
    video: "on-first-retry",
  },
});
