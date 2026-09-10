import { faker } from '@faker-js/faker';
import { expect, test } from '@playwright/test';
import {
  Changes,
  createDefaultTimelineConfig,
  generateTimelineData,
  TimelineData,
  toAssetResponseDto,
} from 'src/ui/generators/timeline';
import { setupBaseMockApiRoutes } from 'src/ui/mock-network/base-network';
import { setupTimelineMockApiRoutes, TimelineTestContext } from 'src/ui/mock-network/timeline-network';

test.describe('Duplicates utility', () => {
  let adminUserId: string;
  let timelineRestData: TimelineData;
  const testContext = new TimelineTestContext();
  const changes: Changes = {
    albumAdditions: [],
    assetDeletions: [],
    assetArchivals: [],
    assetFavorites: [],
  };

  test.beforeAll(() => {
    adminUserId = faker.string.uuid();
    testContext.adminId = adminUserId;
    timelineRestData = generateTimelineData({ ...createDefaultTimelineConfig(), ownerId: adminUserId });
  });

  test.beforeEach(async ({ context }) => {
    await setupBaseMockApiRoutes(context, adminUserId);
    await setupTimelineMockApiRoutes(context, timelineRestData, changes, testContext);

    const assets = timelineRestData.buckets
      .values()
      .toArray()
      .flat()
      .slice(0, 2)
      .map((asset) => toAssetResponseDto(asset));

    await context.route('**/api/duplicates', async (route, request) => {
      if (request.method() !== 'GET') {
        return route.fallback();
      }

      return route.fulfill({
        status: 200,
        contentType: 'application/json',
        json: [
          { duplicateId: faker.string.uuid(), assets, maxSimilarity: 0.97, suggestedKeepAssetIds: [assets[0].id] },
        ],
      });
    });

    await context.route('**/api/assets/*/thumbnail?*', (route) =>
      route.fulfill({
        status: 200,
        contentType: 'image/png',
        body: Buffer.from(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M/wHwAF/gL+X6sAAAAASUVORK5CYII=',
          'base64',
        ),
      }),
    );
  });

  test('lays out duplicate actions consecutively', async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 720 });
    await page.goto('/utilities/duplicates');

    const selectTrashAll = page.getByRole('button', { name: 'Select trash all' });
    const trashSelected = page.getByRole('button', { name: 'Trash 1' });
    await expect(selectTrashAll).toBeVisible();
    await expect(trashSelected).toBeVisible();

    const selectTrashAllBox = await selectTrashAll.boundingBox();
    const trashSelectedBox = await trashSelected.boundingBox();
    expect(selectTrashAllBox).not.toBeNull();
    expect(trashSelectedBox).not.toBeNull();
    expect(trashSelectedBox!.x - (selectTrashAllBox!.x + selectTrashAllBox!.width)).toBeLessThanOrEqual(24);
  });
});
