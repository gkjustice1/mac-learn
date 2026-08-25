/**
 * @param {string | undefined} preferredSecretKey
 * @param {string | undefined} legacyServiceRoleKey
 */
export function resolveSupabaseSecretKey(
  preferredSecretKey,
  legacyServiceRoleKey
) {
  return (
    preferredSecretKey?.trim() ||
    legacyServiceRoleKey?.trim() ||
    undefined
  );
}
