export function isAdminEmail(
  email: string | null | undefined,
  raw: string | undefined,
) {
  if (!email) return false;
  const allowed = (raw ?? '')
    .split(',')
    .map((item) => item.trim().toLowerCase())
    .filter(Boolean);
  return allowed.includes(email.trim().toLowerCase());
}
