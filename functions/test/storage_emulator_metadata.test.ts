/**
 * Prerequisite guard for the identity-verification immutability check.
 *
 * The submitted CNI/selfie objects are immutable once uploaded: the Storage
 * rules allow `create` only, and the server additionally freezes `generation`
 * and `md5Hash` at submission time and re-verifies them when a reviewer
 * decides. That second guard is only provable in tests if the Storage emulator
 * actually reports both fields through the Admin SDK.
 *
 * This suite exists so that a firebase-tools upgrade that stops reporting them
 * turns the test run red immediately, instead of silently reducing the
 * immutability guard to a single (untested) layer.
 */
import * as admin from 'firebase-admin';

// Importing the functions entrypoint initializes the default app.
import '../src/index';

const PREFIX = 'private/identity/probe-uid/probe-batch';

describe('Storage emulator metadata (immutability guard prerequisite)', () => {
  it('is reachable through the Admin SDK', () => {
    expect(process.env.STORAGE_EMULATOR_HOST).toBeDefined();
  });

  it('reports generation and md5Hash on an uploaded object', async () => {
    const file = admin.storage().bucket().file(`${PREFIX}/recto.jpg`);
    await file.save(Buffer.from('fake-jpeg-bytes'), {
      contentType: 'image/jpeg',
    });

    const [metadata] = await file.getMetadata();

    expect(metadata.generation).toBeDefined();
    expect(String(metadata.generation).length).toBeGreaterThan(0);
    expect(metadata.md5Hash).toBeDefined();
    expect(String(metadata.md5Hash).length).toBeGreaterThan(0);

    await file.delete();
  });

  it('changes the generation when the same path is overwritten', async () => {
    // The server compares the frozen fingerprint against the live one. If the
    // emulator reused a generation across writes, a swapped image would slip
    // through the check that is supposed to catch it.
    const file = admin.storage().bucket().file(`${PREFIX}/verso.jpg`);

    await file.save(Buffer.from('first-bytes'), { contentType: 'image/jpeg' });
    const [before] = await file.getMetadata();

    await file.save(Buffer.from('second-bytes-different'), {
      contentType: 'image/jpeg',
    });
    const [after] = await file.getMetadata();

    expect(after.generation).not.toEqual(before.generation);
    expect(after.md5Hash).not.toEqual(before.md5Hash);

    await file.delete();
  });
});
