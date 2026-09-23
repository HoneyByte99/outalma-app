// The three phone callables against the LIVE Twilio client, with only the HTTP
// call faked (`setTwilioTransport`). auth_phone.test.ts swaps the whole client
// out, so nothing there runs the code that reads Twilio's answer: this file is
// where that code is held.
//
// Every reply below is shaped like the one Twilio sends in production. The
// transport throws on any call a test did not plan, so a forgotten stub fails
// loudly instead of reaching verify.twilio.com.
import functionsTest from 'firebase-functions-test';

const tf = functionsTest({
  projectId: 'demo-outalma',
  storageBucket: 'demo-outalma.appspot.com',
});

// Read by SecretParam.value() at call time. Without them the live client would
// log a warning per call and build an unusable Authorization header.
process.env.OTP_HASH_KEY = 'test-hmac-key';
process.env.TWILIO_ACCOUNT_SID = 'ACtest';
process.env.TWILIO_AUTH_TOKEN = 'test-token';
process.env.TWILIO_VERIFY_SERVICE_SID = 'VAtest';

import * as fns from '../src/index';
import {
  resetTwilioClient,
  resetTwilioTransport,
  setTwilioTransport,
  TwilioTransport,
} from '../src/auth_phone';
import { clearFirestore } from './helpers';
import { inspect } from 'util';

// The RAW logger module, the very instance auth_phone.ts reads through its
// namespace import. firebase-functions' logger has no __esModule flag, so an
// `import * as` here would hand back a wrapper of getters that cannot be spied.
const rawLogger = jest.requireActual<typeof import('firebase-functions/logger')>(
  'firebase-functions/logger'
);

const wrap = (fn: unknown) => tf.wrap(fn as never);

// Accepted by today's format check and left unchanged by any normalisation,
// so every call below does reach the transport.
const SN = '+221771234567';

type Endpoint = 'Verifications' | 'VerificationCheck';
type Reply = { status: number; json: unknown };

function fakeTwilio() {
  const calls: Array<{ endpoint: Endpoint; to: string }> = [];
  const replies: Partial<Record<Endpoint, (to: string) => Reply>> = {};
  const transport: TwilioTransport = async (url, _auth, body) => {
    const endpoint: Endpoint | null = url.endsWith('/VerificationCheck')
      ? 'VerificationCheck'
      : url.endsWith('/Verifications')
        ? 'Verifications'
        : null;
    if (endpoint === null) throw new Error(`unexpected Twilio URL: ${url}`);
    const reply = replies[endpoint];
    if (!reply) throw new Error(`no reply planned for ${endpoint}`);
    calls.push({ endpoint, to: body.To ?? '' });
    return reply(body.To ?? '');
  };
  return { calls, replies, transport };
}

const approved = (): Reply => ({
  status: 200,
  json: { status: 'approved', valid: true },
});

/// What Twilio answers a Check once the verification is gone: expired after
/// ten minutes, already approved, or deleted after too many attempts.
const verificationGone = (): Reply => ({
  status: 404,
  json: {
    code: 20404,
    message:
      'The requested resource /v2/Services/VAtest/VerificationCheck was not found',
    more_info: 'https://www.twilio.com/docs/errors/20404',
    status: 404,
  },
});

let twilio = fakeTwilio();

const signIn = (phone: string, code = '123456') =>
  wrap(fns.verifyPhoneOtpAndSignIn)({ data: { phone, code } } as never);

beforeEach(async () => {
  await clearFirestore();
  twilio = fakeTwilio();
  resetTwilioClient();
  setTwilioTransport(twilio.transport);
});

afterAll(() => {
  resetTwilioTransport();
  tf.cleanup();
});

/// A code Twilio still knows but that does not match: HTTP 200, not approved.
const wrongCode = (): Reply => ({
  status: 200,
  json: { status: 'pending', valid: false },
});

const signUp = (phone: string, code = '123456') =>
  wrap(fns.verifyPhoneOtpAndSignUp)({
    data: {
      phone,
      code,
      displayName: 'Test User',
      country: 'SN',
      gender: 'male',
    },
  } as never);

/// The refusal a caller sees, reduced to what reaches the app.
async function refusal(call: Promise<unknown>) {
  try {
    await call;
  } catch (e) {
    const err = e as { code?: string; message?: string };
    return { code: err.code, message: err.message };
  }
  throw new Error('the call was expected to be refused');
}

describe('verifyPhoneOtpAndSignIn through the live client', () => {
  it('lets an approved code through', async () => {
    twilio.replies.VerificationCheck = approved;
    await expect(signIn(SN)).resolves.toMatchObject({ newUser: true });
    expect(twilio.calls).toEqual([{ endpoint: 'VerificationCheck', to: SN }]);
  });

  it('refuses a verification that is gone as an invalid or expired code', async () => {
    // Seen three times in production (2026-09-11 twice, 2026-09-21): the user
    // typed a code older than ten minutes, or one already used, and was told
    // "an error occurred" instead of being sent back for a new code.
    twilio.replies.VerificationCheck = verificationGone;
    await expect(signIn(SN)).rejects.toMatchObject({ code: 'permission-denied' });
    expect(twilio.calls).toEqual([{ endpoint: 'VerificationCheck', to: SN }]);
  });

  it('says exactly what it says for a wrong code, so nobody can tell a verification is pending', async () => {
    twilio.replies.VerificationCheck = verificationGone;
    const gone = await refusal(signIn(SN));
    twilio.replies.VerificationCheck = wrongCode;
    const wrong = await refusal(signIn(SN));
    expect(gone).toEqual(wrong);
    expect(wrong.code).toBe('permission-denied');
  });
});

describe('verifyPhoneOtpAndSignUp through the live client', () => {
  it('refuses a verification that is gone as an invalid or expired code', async () => {
    twilio.replies.VerificationCheck = verificationGone;
    await expect(signUp(SN)).rejects.toMatchObject({ code: 'permission-denied' });
    expect(twilio.calls).toEqual([{ endpoint: 'VerificationCheck', to: SN }]);
  });
});

/// What Twilio answers a Start for a number it will not text. The real reply
/// echoes the number back in its message.
const invalidNumber = (to: string): Reply => ({
  status: 400,
  json: {
    code: 60200,
    message: `Invalid parameter \`To\`: ${to}`,
    more_info: 'https://www.twilio.com/docs/errors/60200',
    status: 400,
  },
});

const requestOtp = (phone: string) =>
  wrap(fns.requestPhoneOtp)({ data: { phone } } as never);

describe('requestPhoneOtp through the live client', () => {
  it('sends through the live client', async () => {
    twilio.replies.Verifications = () => ({ status: 201, json: { status: 'pending' } });
    await expect(requestOtp(SN)).resolves.toMatchObject({ channel: 'sms' });
    expect(twilio.calls).toEqual([{ endpoint: 'Verifications', to: SN }]);
  });

  it('refuses a number Twilio will not text as an invalid number, not a network error', async () => {
    // Seen twice in production on 2026-09-11: the app told the user to check
    // their connection, when the number itself was malformed.
    twilio.replies.Verifications = invalidNumber;
    await expect(requestOtp(SN)).rejects.toMatchObject({ code: 'invalid-argument' });
    expect(twilio.calls).toEqual([{ endpoint: 'Verifications', to: SN }]);
  });
});

/// Every level, not just `error`: a leak moved to `warn` must still be seen.
const LEVELS = ['debug', 'info', 'log', 'warn', 'error', 'write'] as const;

function spyLogger() {
  const spies = LEVELS.map((level) =>
    jest.spyOn(rawLogger, level).mockImplementation(() => undefined)
  );
  const calls = () => spies.flatMap((spy) => spy.mock.calls as unknown[][]);
  return {
    calls,
    /// The calls made at one level only.
    at: (level: (typeof LEVELS)[number]) =>
      spies[LEVELS.indexOf(level)]!.mock.calls as unknown[][],
    // depth: null, or a nested echo past two levels would print as [Object].
    text: () =>
      calls()
        .map((args) => args.map((a) => inspect(a, { depth: null })).join(' '))
        .join('\n'),
    restore: () => spies.forEach((spy) => spy.mockRestore()),
  };
}

/// A Check refused on its `To`: the real reply echoes the number back, as the
/// Start one does, so the Check site has something to leak too.
const checkInvalidNumber = (to: string): Reply => ({
  status: 400,
  json: {
    code: 60200,
    message: `Invalid parameter \`To\`: ${to}`,
    status: 400,
  },
});

describe('Twilio refusals are logged without the phone number (S12)', () => {
  let log: ReturnType<typeof spyLogger>;
  beforeEach(() => {
    log = spyLogger();
  });
  afterEach(() => log.restore());

  /// The digits Twilio actually received, read off the fake transport rather
  /// than off a constant of this test: what reaches Twilio is what it echoes.
  const sentDigits = () => {
    expect(twilio.calls).toHaveLength(1);
    return twilio.calls[0]!.to.replace(/\D/g, '');
  };

  it('on the Start call', async () => {
    twilio.replies.Verifications = invalidNumber;
    await expect(requestOtp(SN)).rejects.toBeDefined();
    expect(log.calls()).toContainEqual([
      expect.any(String),
      { status: 400, twilioCode: 60200 },
    ]);
    expect(log.text()).not.toContain(sentDigits());
  });

  it('on the Check call', async () => {
    twilio.replies.VerificationCheck = checkInvalidNumber;
    await expect(signIn(SN)).rejects.toBeDefined();
    expect(log.calls()).toContainEqual([
      expect.any(String),
      { status: 400, twilioCode: 60200 },
    ]);
    expect(log.text()).not.toContain(sentDigits());
  });
});

describe('the level of a Twilio refusal line', () => {
  let log: ReturnType<typeof spyLogger>;
  beforeEach(() => {
    log = spyLogger();
  });
  afterEach(() => log.restore());

  const line = [expect.any(String), { status: 400, twilioCode: 60200 }];

  it('is a warning when the user caused it, so a bad number raises no alert', async () => {
    twilio.replies.Verifications = invalidNumber;
    await expect(requestOtp(SN)).rejects.toMatchObject({ code: 'invalid-argument' });
    expect(log.at('warn')).toEqual([line]);
    expect(log.at('error')).toEqual([]);
  });

  it('is an error when the failure still reads as an outage', async () => {
    // A 60200 on the CHECK is not one of the codes read as a dead code, so it
    // stays `unavailable`: something is wrong on our side, and it must alert.
    twilio.replies.VerificationCheck = checkInvalidNumber;
    await expect(signIn(SN)).rejects.toMatchObject({ code: 'unavailable' });
    expect(log.at('error')).toEqual([line]);
    expect(log.at('warn')).toEqual([]);
  });
});
