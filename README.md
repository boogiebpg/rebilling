# Rebilling

Implementation of a system for automatic subscription rebilling, which is handling scenarios of insufficient funds on the card.

Usage example:
```
curl -X POST "http://localhost:3000/paymentIntents/create" -d "amount=100&subscription_id=8"
```
