# Postmill Voting Bug in Visual Web Arena

## What’s happening

In the Visual Web Arena (VWA) setup, the Postmill Reddit clone appears to have a voting bug: posts that start with thousands of votes drop to `1` when anyone votes on them.

The bug isn’t in Postmill itself — it appears to be in how the VWA dataset was imported. A [testcase here](https://github.com/bgrins/vwa_reddit_optimized/blob/5f297471b9851f813bb6e6f4d5a544aab6f37387/tests/reddit-forum.spec.js#L354) captures the expected failure.

Example: a post shows `7,502` votes → you upvote → it resets to `1`.

## Why it happens

* Postmill keeps vote counts in two places:

  * `submissions.net_score` → preloaded Reddit scores
  * `submission_votes` → the actual vote records

* The VWA import only filled in `net_score` and **didn’t add matching vote records**.

* When you vote, Postmill recalculates based only on `submission_votes`. Since it was empty, you’re the only voter → `1`.

## Example data

| Post ID | Title                         | net\_score | Votes in DB |
| ------- | ----------------------------- | ---------- | ----------- |
| 110715  | Blue Jay pestering Bald Eagle | 7,502      | 0           |
| 41616   | Which fruit…                  | 56,711     | 0           |
| 45604   | A Trejo Thanksgiving          | 1          | 1           |


## How to check

Run this in your container to find posts with “orphaned” scores:

```bash
docker exec [container] psql -U postmill -d postmill -c "
  SELECT COUNT(*) 
  FROM submissions 
  WHERE net_score > 0
  AND id NOT IN (SELECT DISTINCT submission_id FROM submission_votes);"
```
