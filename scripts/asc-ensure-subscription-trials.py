#!/usr/bin/env python3
"""Ensure both Streaks+ subscriptions have a one-week free trial everywhere."""
from __future__ import annotations

import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from asc_lib import ASCClient, bearer_token, list_all, load_credentials

SUBSCRIPTION_IDS = {
    "monthly": "6768126548",
    "yearly": "6768126260",
}


def create_trial(client: ASCClient, subscription_id: str, territory_id: str) -> None:
    client.post(
        "/subscriptionIntroductoryOffers",
        {
            "data": {
                "type": "subscriptionIntroductoryOffers",
                "attributes": {
                    "duration": "ONE_WEEK",
                    "offerMode": "FREE_TRIAL",
                    "numberOfPeriods": 1,
                    "startDate": "2026-07-27",
                },
                "relationships": {
                    "subscription": {
                        "data": {"type": "subscriptions", "id": subscription_id}
                    },
                    "territory": {
                        "data": {"type": "territories", "id": territory_id}
                    },
                },
            }
        },
    )


def main() -> None:
    key_id, issuer_id, key_path = load_credentials()
    client = ASCClient(bearer_token(key_id, issuer_id, key_path))
    territories = [item["id"] for item in list_all(client, "/territories?limit=200")]

    for label, subscription_id in SUBSCRIPTION_IDS.items():
        existing = list_all(client, f"/subscriptions/{subscription_id}/introductoryOffers")
        if len(existing) >= len(territories):
            print(f"{label}: {len(existing)} trials already cover all {len(territories)} territories")
            continue

        created = 0
        unchanged = 0
        for territory_id in territories:
            try:
                create_trial(client, subscription_id, territory_id)
                created += 1
                print(f"{label}: created {territory_id}")
            except RuntimeError as error:
                message = str(error)
                if "INTRODUCTORY_OFFER_ALREADY_EXISTS" in message or "already has an introductory offer" in message:
                    unchanged += 1
                else:
                    raise
            time.sleep(0.12)
        print(f"{label}: created {created}, existing {unchanged}")


if __name__ == "__main__":
    main()
