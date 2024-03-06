import requests

def get_versions():
    headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36 Edge/16.16299"}
    canary = requests.get("https://aka.ms/canarychannellatest", headers=headers).url.split("preview-build-")[1].split("-")[0]
    dev = requests.get("https://aka.ms/DevLatest", headers=headers).url.split("preview-build-")[1].split("-")[0]
    beta = requests.get("https://aka.ms/BetaLatest", headers=headers).url.split("preview-build-")[1].split("-")[0]
    return canary, dev, beta

for version in get_versions():
    print(version)