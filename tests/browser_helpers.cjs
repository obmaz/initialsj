// Observe the running game instead of assuming shader warm-up fits a fixed delay.
async function startTour(page) {
  await page.locator('#canvas').focus();
  const deadline = Date.now() + 60000;
  while (Date.now() < deadline) {
    if (await page.evaluate(() => !!window.initialsjFileAudio?.target.active)) return;
    await page.keyboard.press('Enter');
    await page.waitForTimeout(250);
  }
  throw new Error('The menu and garage must lead to an active countdown or race');
}
module.exports = {startTour};
