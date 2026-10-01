import { isAdminEmail } from './admin-email';

describe('isAdminEmail', () => {
  it('matches one of the configured emails, ignoring case and spaces', () => {
    expect(isAdminEmail('Agus@gmail.com', ' otro@x.com , agus@gmail.com ')).toBe(true);
  });

  it('rejects everyone when the list is empty', () => {
    expect(isAdminEmail('agus@gmail.com', '')).toBe(false);
    expect(isAdminEmail(null, 'agus@gmail.com')).toBe(false);
  });
});
