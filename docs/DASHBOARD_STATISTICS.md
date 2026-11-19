# Dashboard statistics

Downloads are successful PDF/Word export deliveries for the current account on
this device. They are stored under an owner-specific SharedPreferences key and
exposed through `downloadCountProvider(userId)`. Completing an export invalidates
that owner's provider, so Home updates without restarting. The previous global
`stats.exports.count` has no owner and is discarded rather than assigned to the
next signed-in account. Counts are not a cross-device download ledger.

Settings account deletion goes through `SessionController.deleteAccount(userId)`.
It verifies that the confirmation still belongs to the signed-in account, waits
for backend deletion, clears that account's local export count and then performs
complete sign-out and cache invalidation. Failed backend deletion leaves the
count and session intact. Signing out normally preserves the owner's count.

Portfolio views are cumulative authorized opens of share links. The existing
Supabase resolver returns `shareId`; after successful resolution the client calls
the deployed `record_share_view` RPC once. Invalid, expired, revoked, unpublished
or incorrectly password-protected links never reach counting. Counter failure
does not prevent viewing. Local resolution follows the same authorization order.
This measures opens, including repeat visits, rather than unique visitors.

Home totals shares for every portfolio belonging to the current account. CVs,
other owners and deleted documents do not contribute. Historical views on revoked
links still contribute while their portfolio exists. Account deletion cascades
away documents/shares, so the deleted account contributes zero. Selecting Home or
pulling to refresh reloads shares; resolving a public link also invalidates the
owner's cached shares in the same app.

Verification covers account isolation, legacy total removal, successful/failed
deletion, stale confirmations, Home refresh/account switching, all portfolio
aggregation and authorized/denied Supabase resolver calls. Existing portfolio,
persistence, delivery and biometric regression tests passed. A live no-op call to
`record_share_view` with a random nonexistent share returned HTTP 204, confirming
that the deployed counter accepts anonymous visitors without changing real data.
