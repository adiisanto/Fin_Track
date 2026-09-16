import httpx

base_url = "http://localhost:8000/api/v1"
client = httpx.Client(base_url=base_url)

# 1. Login as admin
resp = client.post("/auth/login", json={"email": "admin@fintrack.com", "password": "admin123"})
if resp.status_code != 200:
    print("Login failed!", resp.text)
    exit(1)

data = resp.json()["data"]
token = data["tokens"]["access_token"]
headers = {"Authorization": f"Bearer {token}"}

print("1. Login Success as admin")

# 2. Add currency
resp = client.post("/admin/currencies", json={
    "code": "JPY",
    "name": "Japanese Yen",
    "symbol": "¥",
    "is_active": True
}, headers=headers)

if resp.status_code == 201:
    print("2. Add currency JPY Success")
else:
    print("2. Add currency Failed", resp.text)

# 3. Check get currencies
resp = client.get("/currencies")
currencies = [c["code"] for c in resp.json()["data"]]
print("3. Currencies list:", currencies)

# 4. Try add duplicate currency
resp = client.post("/admin/currencies", json={
    "code": "JPY",
    "name": "Japanese Yen",
    "symbol": "¥",
    "is_active": True
}, headers=headers)
if resp.status_code == 409:
    print("4. Add duplicate currency JPY Failed (as expected)")
else:
    print("4. Add duplicate check failed", resp.text)

# 5. Try delete currency JPY
resp = client.delete("/admin/currencies/JPY", headers=headers)
if resp.status_code == 200:
    print("5. Delete currency JPY Success")
else:
    print("5. Delete currency Failed", resp.text)

# 6. Try delete currency IDR (seed data)
# NOTE: To test failure we should try to delete IDR, wait IDR doesn't have transactions yet. Let's create a transaction first.
resp = client.get("/payment-methods")
pm_id = resp.json()["data"][0]["id"]

resp = client.post("/transactions", json={
    "type": "EXPENSE",
    "currency_code": "USD",
    "amount": 100,
    "payment_method_id": pm_id
}, headers=headers)
print("Created transaction with USD:", resp.status_code)

resp = client.delete("/admin/currencies/USD", headers=headers)
if resp.status_code == 400:
    print("6. Delete currency USD (has tx) Failed (as expected)")
else:
    print("6. Delete currency USD check failed", resp.text)

print("All tests completed.")
