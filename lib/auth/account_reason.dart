/// Why the app is asking a guest (or an unverified user) for an account.
/// Only changes the wording of the prompt; which gate applies is decided by
/// calling `requireAccount` or `requireVerifiedAccount`.
enum AccountReason {
  // Login tier
  save,
  like,
  cook,
  collections,
  shoppingList,
  share,
  report,
  block,
  notifications,
  following,
  account,
  sessionExpired,

  // Verified tier
  comment,
  follow,
  create,
}
