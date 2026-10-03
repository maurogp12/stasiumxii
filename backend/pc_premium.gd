extends RefCounted

## Spec 4.18. Every premium check goes through is_premium().
## Offline testing returns true so houses, pets and mounts can be tried
## before a payment provider exists. The balance report still prints the
## free clock and the premium clock as two profiles.

static func is_premium() -> bool:
	return true
