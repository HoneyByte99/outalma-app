// Pure mapping of Twilio Verify's error replies. One case per condition: the
// guards are ORs of redundant conditions (an HTTP status and a Twilio code),
// and a table that always sent both would let either half be deleted unseen.
import {
  checkFailure,
  INVALID_OR_EXPIRED_CODE,
  startFailure,
  twilioLogFields,
} from '../src/twilio_errors';

describe('checkFailure', () => {
  it.each([
    ['a 404 with no body', 404, null],
    ['Twilio code 20404 alone', 400, { code: 20404 }],
    ['Twilio code 60202, attempts spent', 429, { code: 60202 }],
  ])('reads %s as an invalid or expired code', (_label, status, json) => {
    expect(checkFailure(status, json)).toMatchObject({
      code: 'permission-denied',
      message: INVALID_OR_EXPIRED_CODE,
    });
  });

  it.each([
    ['an unknown Twilio code', 400, { code: 99999 }],
    ['a server error', 500, null],
    ['a code that is not a number', 400, { code: '20404' }],
    ['a body that is not an object', 400, 'not json'],
  ])('keeps %s an outage', (_label, status, json) => {
    expect(checkFailure(status, json)).toMatchObject({ code: 'unavailable' });
  });
});

describe('startFailure', () => {
  it.each([
    ['Twilio code 60200, invalid parameter', 400, { code: 60200 }],
    ['Twilio code 60205, landline', 400, { code: 60205 }],
  ])('reads %s as an invalid number', (_label, status, json) => {
    expect(startFailure(status, json)).toMatchObject({ code: 'invalid-argument' });
  });

  it.each([
    ['an unknown Twilio code', 400, { code: 99999 }],
    ['a server error', 500, null],
    ['a 404, which says nothing about the number', 404, null],
  ])('keeps %s an outage', (_label, status, json) => {
    expect(startFailure(status, json)).toMatchObject({ code: 'unavailable' });
  });
});

describe('twilioLogFields', () => {
  it('keeps the status and the numeric code, and drops the echoed message', () => {
    const reply = { code: 60200, message: 'Invalid parameter `To`: +221771234567' };
    const fields = twilioLogFields(400, reply);
    expect(fields).toEqual({ status: 400, twilioCode: 60200 });
    expect(JSON.stringify(fields)).not.toContain('771234567');
  });

  it.each([
    ['no body', null],
    ['a body that is not an object', 'not json'],
    ['a code that is not a number', { code: '60200' }],
  ])('reports %s with a null code', (_label, json) => {
    expect(twilioLogFields(500, json)).toEqual({ status: 500, twilioCode: null });
  });
});
