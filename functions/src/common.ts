import { HttpsError } from 'firebase-functions/v2/https';

export function assertAuthenticated(uid: string | undefined): asserts uid is string {
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }
}

export function requireString(value: unknown, field: string): string {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new HttpsError('invalid-argument', `Field '${field}' must be a non-empty string.`);
  }
  return value.trim();
}

export function requireBoolean(value: unknown, field: string): boolean {
  if (typeof value !== 'boolean') {
    throw new HttpsError('invalid-argument', `Field '${field}' must be a boolean.`);
  }
  return value;
}

export function assertAdminClaim(claimAdmin: unknown): void {
  if (claimAdmin !== true) {
    throw new HttpsError('permission-denied', 'Admin privileges required.');
  }
}

export function assertAdminOrModeratorClaim(token: Record<string, unknown> | undefined): void {
  if (token?.admin !== true && token?.moderator !== true) {
    throw new HttpsError('permission-denied', 'Admin or moderator privileges required.');
  }
}
