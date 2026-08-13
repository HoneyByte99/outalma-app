// ---------------------------------------------------------------------------
// Staff action audit trail
// ---------------------------------------------------------------------------
//
// Moved out of index.ts unchanged so that new callables can reuse it without
// importing the entrypoint. Firestore is obtained lazily for the same reason as
// in notify.ts: an eager admin.firestore() would run before initializeApp().
//
// NOTE for callers handling identity documents: `admin_logs` survives
// deleteMyAccount, which only removes services, the provider profile and the
// user document. Never pass extracted identity fields (card number, names) or a
// free-text reason through `notes`: that would create a retention with no purge
// path behind it. Log an opaque marker and keep the text on its own document.

import * as admin from 'firebase-admin';

const db = () => admin.firestore();

export interface AdminLogEntry {
  actorUid: string;
  action: string;
  targetType: string;
  targetId: string;
  notes?: string;
}

export function adminLogPayload(data: AdminLogEntry): Record<string, unknown> {
  return {
    actorUid: data.actorUid,
    action: data.action,
    targetType: data.targetType,
    targetId: data.targetId,
    notes: data.notes ?? null,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  };
}

export async function writeAdminLog(data: AdminLogEntry): Promise<void> {
  await db().collection('admin_logs').add(adminLogPayload(data));
}

/// Same entry, written inside an existing transaction so the trail cannot be
/// lost when the action it records succeeds. Used by the identity decision
/// callables, where an untraced decision on an identity document would silently
/// break the "every staff action is traced" invariant.
export function writeAdminLogTx(
  tx: admin.firestore.Transaction,
  data: AdminLogEntry
): void {
  tx.set(db().collection('admin_logs').doc(), adminLogPayload(data));
}
