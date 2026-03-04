import os
import asyncio
from playwright.async_api import async_playwright

BROWSERLESS_HOST = os.environ.get(
    "BROWSERLESS_HOST",
    "browserless-service.browserless.svc.cluster.local"
)
BROWSERLESS_PORT = os.environ.get("BROWSERLESS_PORT", "3000")
BROWSERLESS_TOKEN = os.environ.get("BROWSERLESS_TOKEN", "")

BROWSERLESS_URL = f"ws://{BROWSERLESS_HOST}:{BROWSERLESS_PORT}/chromium/playwright"
if BROWSERLESS_TOKEN:
    BROWSERLESS_URL += f"?token={BROWSERLESS_TOKEN}"

TASK_ID = os.environ.get("TASK_ID", "unknown")


async def main():
    print(f"Starting generate_report for task: {TASK_ID}")
    print(f"Connecting to browserless: {BROWSERLESS_URL}")

    async with async_playwright() as p:
        browser = await p.chromium.connect(BROWSERLESS_URL)
        page = await browser.new_page()

        print("Navigating to Wikipedia...")
        await page.goto("https://blazedemo.com/index.php")

        print("Taking screenshot...")
        await page.screenshot(path=f"/data/output/screenshot-{TASK_ID}.png")

        print(f"Screenshot saved to /data/output/screenshot-{TASK_ID}.png")

        await browser.close()

    print("Done!")


if __name__ == "__main__":
    asyncio.run(main())