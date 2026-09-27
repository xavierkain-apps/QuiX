# Stats

Where each number comes from. None of them needs a cookie or collects anything personal.

| What | Where | Notes |
|---|---|---|
| Site visits, referrers, countries | [Plausible](https://analytics.xavierkain.fr/quix.xavier-kain.fr) (self-hosted Community Edition) | Site-specific script (`pa-….js`) in every page head; the CSP allows `analytics.xavierkain.fr`. |
| Sign-ups before download | Plausible goal `Signup` (prop `lang`), and `~/quix.xavier-kain.fr/quix-inscriptions.jsonl` on the server | The register is the source of truth: Plausible misses visitors with blockers. |
| Feedback sent | Plausible goal `Feedback` (prop `type`), and `~/quix-retours.jsonl` | |
| Downloads of the app | `gh api repos/xavierkain-apps/QuiX/releases --jq '.[] \| "\(.tag_name) \(.assets[].download_count)"'` | Counts every fetch of `QuiX.zip`, test downloads and Sparkle updates included. |
| Installed copies in use | `GET /appcast.xml` in the o2switch access logs, user-agent `QuiX/<version> Sparkle/<version>` | Each running copy checks once a day. Count distinct IPs per day for active installs, and group by `QuiX/x.y` for the version spread. Logs: `~/access-logs/` (current), `~/logs/*.gz` (monthly archives). |

The two custom events only show in Plausible once they are added as goals there:
*Site settings → Goals → Add goal → Custom event*, names `Signup` and `Feedback`.
