import requests

fx = requests.get("https://open.er-api.com/v6/latest/USD", timeout=10).json()
print("USD/EGP:", fx["rates"]["EGP"])

crypto = requests.get(
    "https://api.coingecko.com/api/v3/simple/price",
    params={"ids": "bitcoin", "vs_currencies": "usd"},
    timeout=10,
).json()
print("BTC/USD:", crypto["bitcoin"])