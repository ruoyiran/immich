import {
  AssetMediaStatus,
  AssetUploadAction,
  type AssetMediaResponseDto,
  type UserAdminResponseDto,
} from '@immich/sdk';
import * as sdk from '@immich/sdk';
import { get } from 'svelte/store';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { authManager } from '$lib/managers/auth-manager.svelte';
import { uploadManager } from '$lib/managers/upload-manager.svelte';
import { uploadAssetsStore } from '$lib/stores/upload';
import { UploadState } from '$lib/types';
import * as utils from '$lib/utils';
import { preferencesFactory } from '@test-data/factories/preferences-factory';
import { fileUploadHandler } from './file-uploader';

describe('fileUploader error handling', () => {
  const mockFile = new File(['content'], 'test.jpg', { type: 'image/jpeg' });
  const mockUserObject = { id: 'user-123', email: 'test@example.com' } as UserAdminResponseDto;
  const mockError = new Error('Upload failed');
  const mockUploadResponse = { id: 'mock-id', status: AssetMediaStatus.Created } as AssetMediaResponseDto;

  beforeEach(() => {
    vi.clearAllMocks();
    vi.spyOn(uploadManager, 'getExtensions').mockReturnValue(['.jpg']);
    uploadAssetsStore.reset();
    authManager.reset();
    vi.spyOn(sdk, 'checkBulkUpload').mockResolvedValue({
      results: [{ id: mockFile.name, action: AssetUploadAction.Accept }],
    });
    vi.stubGlobal(
      'Worker',
      class {
        private onMessage?: (event: MessageEvent<{ result: string }>) => void;

        addEventListener(type: string, listener: (event: MessageEvent<{ result: string }>) => void) {
          if (type === 'message') {
            this.onMessage = listener;
          }
        }

        postMessage() {
          queueMicrotask(() => this.onMessage?.(new MessageEvent('message', { data: { result: '0123456789abcdef' } })));
        }

        terminate() {}
      },
    );
  });

  for (const [name, mockUser] of [
    ['logged-in users', true],
    ['anonymous users', false],
  ] as const) {
    describe(`for ${name}`, () => {
      beforeEach(() => {
        if (mockUser) {
          authManager.setUser(mockUserObject);
        }
      });

      it(`should transition successful uploads to done`, async () => {
        vi.spyOn(utils, 'uploadRequest').mockResolvedValue({ status: 200, data: mockUploadResponse });

        await fileUploadHandler({ files: [mockFile] });

        const items = get(uploadAssetsStore);
        expect(items.length).toBe(1);
        expect(items[0].state).toBe(UploadState.DONE);
      });

      it('should capture errors', async () => {
        vi.spyOn(utils, 'uploadRequest').mockRejectedValue(mockError);

        await fileUploadHandler({ files: [mockFile] });

        const items = get(uploadAssetsStore);
        expect(items.length).toBe(1);
        expect(items[0].state).toBe(UploadState.ERROR);
      });
    });
  }

  it('should suppress errors on logout', async () => {
    authManager.setUser(mockUserObject);
    authManager.setPreferences(preferencesFactory.build());
    vi.spyOn(utils, 'uploadRequest').mockImplementationOnce(() => {
      authManager.reset();
      return Promise.reject(mockError);
    });

    await fileUploadHandler({ files: [mockFile] });

    const items = get(uploadAssetsStore);
    expect(items.length).toBe(1);
    expect(items[0].state).toBe(UploadState.STARTED);
  });

  describe('pinned upload compatibility contract', () => {
    beforeEach(() => authManager.setUser(mockUserObject));

    it('uploads an accepted checksum and handles a 201 created response', async () => {
      vi.spyOn(sdk, 'checkBulkUpload').mockResolvedValue({
        results: [{ id: mockFile.name, action: AssetUploadAction.Accept }],
      });
      const upload = vi
        .spyOn(utils, 'uploadRequest')
        .mockResolvedValue({ status: 201, data: { id: 'created-id', status: AssetMediaStatus.Created } });

      expect(await fileUploadHandler({ files: [mockFile] })).toEqual(['created-id']);

      expect(upload).toHaveBeenCalledOnce();
      expect(get(uploadAssetsStore)[0]).toMatchObject({ state: UploadState.DONE, assetId: 'created-id' });
    });

    for (const [name, isTrashed] of [
      ['active', false],
      ['trashed', true],
    ] as const) {
      it(`uses the ${name} bulk-check duplicate without uploading bytes`, async () => {
        vi.spyOn(sdk, 'checkBulkUpload').mockResolvedValue({
          results: [
            {
              id: mockFile.name,
              action: AssetUploadAction.Reject,
              assetId: `${name}-duplicate-id`,
              isTrashed,
            },
          ],
        });
        const upload = vi.spyOn(utils, 'uploadRequest');

        expect(await fileUploadHandler({ files: [mockFile] })).toEqual([`${name}-duplicate-id`]);

        expect(upload).not.toHaveBeenCalled();
        expect(get(uploadAssetsStore)[0]).toMatchObject({
          state: UploadState.DUPLICATED,
          assetId: `${name}-duplicate-id`,
          isTrashed,
        });
      });
    }

    it('handles a 200 duplicate response after an accepted bulk check', async () => {
      vi.spyOn(sdk, 'checkBulkUpload').mockResolvedValue({
        results: [{ id: mockFile.name, action: AssetUploadAction.Accept }],
      });
      vi.spyOn(utils, 'uploadRequest').mockResolvedValue({
        status: 200,
        data: { id: 'raced-duplicate-id', status: AssetMediaStatus.Duplicate },
      });

      expect(await fileUploadHandler({ files: [mockFile] })).toEqual(['raced-duplicate-id']);

      expect(get(uploadAssetsStore)[0]).toMatchObject({
        state: UploadState.DUPLICATED,
        assetId: 'raced-duplicate-id',
      });
    });
  });
});
