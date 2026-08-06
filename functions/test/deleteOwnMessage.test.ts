// Unit tests for the deleteOwnMessage callable Cloud Function.
// Verifies ownership check: only the message sender may soft-delete.
import functionsTest from 'firebase-functions-test';

const tf = functionsTest({ projectId: 'demo-outalma' });

import * as fns from '../src/index';
import * as admin from 'firebase-admin';
import { clearFirestore, seedMessage, getMessage } from './helpers';

type Auth = { uid: string; token?: Record<string, unknown> };

function call(fn: unknown, data: unknown, auth?: Auth): Promise<unknown> {
  const wrapped = tf.wrap(fn as never);
  return wrapped({ data, auth } as never);
}

async function expectReject(p: Promise<unknown>, code: string): Promise<void> {
  await expect(p).rejects.toMatchObject({
    code: expect.stringContaining(code),
  });
}

beforeEach(async () => {
  await clearFirestore();
});

afterAll(async () => {
  tf.cleanup();
  await admin.firestore().terminate();
});

describe('deleteOwnMessage', () => {
  it('rejects an unauthenticated caller', async () => {
    await seedMessage('chat_1', 'msg_1', { senderId: 'alice' });
    await expectReject(
      call(fns.deleteOwnMessage, { chatId: 'chat_1', messageId: 'msg_1' }, undefined),
      'unauthenticated',
    );
  });

  it('rejects a non-owner with permission-denied', async () => {
    await seedMessage('chat_1', 'msg_1', { senderId: 'alice' });
    await expectReject(
      call(
        fns.deleteOwnMessage,
        { chatId: 'chat_1', messageId: 'msg_1' },
        { uid: 'bob' },
      ),
      'permission-denied',
    );
  });

  it('rejects not-found when message does not exist', async () => {
    await expectReject(
      call(
        fns.deleteOwnMessage,
        { chatId: 'chat_1', messageId: 'ghost' },
        { uid: 'alice' },
      ),
      'not-found',
    );
  });

  it('soft-deletes the message when caller is the sender', async () => {
    await seedMessage('chat_1', 'msg_1', { senderId: 'alice', text: 'hello' });

    const result = (await call(
      fns.deleteOwnMessage,
      { chatId: 'chat_1', messageId: 'msg_1' },
      { uid: 'alice' },
    )) as { chatId: string; messageId: string; deleted: boolean };

    expect(result.chatId).toBe('chat_1');
    expect(result.messageId).toBe('msg_1');
    expect(result.deleted).toBe(true);

    const msg = await getMessage('chat_1', 'msg_1');
    expect(msg?.deleted).toBe(true);
    expect(msg?.text).toBeUndefined();
    expect(msg?.deletedBy).toBe('alice');
    expect(msg?.deletedAt).toBeTruthy();
  });

  it('leaves the message unchanged when a non-owner tries to delete', async () => {
    await seedMessage('chat_1', 'msg_1', { senderId: 'alice', text: 'original' });

    await expect(
      call(
        fns.deleteOwnMessage,
        { chatId: 'chat_1', messageId: 'msg_1' },
        { uid: 'charlie' },
      ),
    ).rejects.toBeTruthy();

    const msg = await getMessage('chat_1', 'msg_1');
    expect(msg?.deleted).toBeFalsy();
    expect(msg?.text).toBe('original');
  });
});
