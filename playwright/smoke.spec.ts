import { test, expect } from "@playwright/test";

test.describe("smoke tests", () => {
  test("ログインページが表示される", async ({ page }) => {
    await page.goto("/");
    // 未ログイン時はログインページにリダイレクトされる
    await expect(page).toHaveURL(/login|sign_in/);
  });

  test("管理画面にログインできる", async ({ page }) => {
    // seed ユーザーでログイン
    await page.goto("/users/sign_in");
    await page.fill('[name="user[email]"]', "admin@example.com");
    await page.fill('[name="user[password]"]', "password");
    await page.click('[type="submit"]');

    // ログイン後のダッシュボードが表示される
    await expect(page).not.toHaveURL(/sign_in/);
  });

  test("管理画面の主要ページが200を返す", async ({ page }) => {
    // ログイン
    await page.goto("/users/sign_in");
    await page.fill('[name="user[email]"]', "admin@example.com");
    await page.fill('[name="user[password]"]', "password");
    await page.click('[type="submit"]');
    await expect(page).not.toHaveURL(/sign_in/);

    // 主要管理画面を巡回
    const adminPages = [
      "/admin",
      "/admin/projects",
      "/admin/documents",
    ];

    for (const path of adminPages) {
      const response = await page.goto(path);
      expect(response?.status(), `${path} should return 200`).toBe(200);
    }
  });
});
