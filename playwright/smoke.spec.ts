import { test, expect } from "@playwright/test";

test.describe("smoke tests", () => {
  test("ログインページが表示される", async ({ page }) => {
    await page.goto("/");
    // 未ログイン時はログインページにリダイレクトされる
    await expect(page).toHaveURL(/session\/new/);
  });

  test("管理画面にログインできる", async ({ page }) => {
    await page.goto("/session/new");
    await page.fill('[name="session[email_address]"]', "admin@example.com");
    await page.fill('[name="session[password]"]', "password123!");
    await page.click('[type="submit"]');
    // ログイン後はログインページから離れる
    await expect(page).not.toHaveURL(/session\/new/);
  });

  test("管理画面の主要ページが200を返す", async ({ page }) => {
    // ログイン
    await page.goto("/session/new");
    await page.fill('[name="session[email_address]"]', "admin@example.com");
    await page.fill('[name="session[password]"]', "password123!");
    await page.click('[type="submit"]');
    await expect(page).not.toHaveURL(/session\/new/);

    // 主要管理画面を巡回
    const adminPages = ["/admin", "/admin/projects", "/admin/documents"];
    for (const path of adminPages) {
      const response = await page.goto(path);
      expect(response?.status(), `${path} should return 200`).toBe(200);
    }
  });
});
