#!/usr/bin/env python3
"""Apply the three-tier emerging-market discount plan to Streak Counter subscriptions.
Mirrors ~/vitals/scripts/asc-discount-emerging-markets.py (same tiers/ceilings)."""
import sys, time
sys.path.insert(0, "scripts")
from asc_lib import load_credentials, bearer_token, ASCClient
from datetime import date, timedelta

TIERS = {
    "IND":(4.99,0.69),"PAK":(4.99,0.69),"BGD":(4.99,0.69),"IDN":(4.99,0.69),
    "VNM":(4.99,0.69),"PHL":(4.99,0.69),"EGY":(4.99,0.69),"NGA":(4.99,0.69),
    "TUR":(7.99,0.99),"BRA":(7.99,0.99),"MEX":(7.99,0.99),"COL":(7.99,0.99),
    "CHL":(7.99,0.99),"THA":(7.99,0.99),"MYS":(7.99,0.99),"POL":(7.99,0.99),
    "HUN":(7.99,0.99),"ROU":(7.99,0.99),"ZAF":(7.99,0.99),"RUS":(7.99,0.99),
    "SAU":(11.99,1.49),"ARE":(11.99,1.49),"CZE":(11.99,1.49),"CHN":(11.99,1.49),
}
FX = {"INR":0.012,"PKR":0.0036,"BDT":0.0082,"IDR":0.000062,"VND":0.0000395,
    "PHP":0.0173,"EGP":0.020,"NGN":0.00065,"TRY":0.029,"BRL":0.20,"MXN":0.049,
    "COP":0.00024,"CLP":0.0011,"THB":0.029,"MYR":0.22,"PLN":0.25,"HUF":0.0028,
    "RON":0.22,"ZAR":0.055,"RUB":0.011,"SAR":0.27,"AED":0.27,"CZK":0.044,"CNY":0.14,"USD":1.0}
TERRITORY_CURRENCY = {"IND":"INR","PAK":"PKR","BGD":"BDT","IDN":"IDR","VNM":"VND",
    "PHL":"PHP","EGY":"EGP","NGA":"NGN","TUR":"TRY","BRA":"BRL","MEX":"MXN","COL":"COP",
    "CHL":"CLP","THA":"THB","MYS":"MYR","POL":"PLN","HUN":"HUF","ROU":"RON","ZAF":"ZAR",
    "RUS":"RUB","SAU":"SAR","ARE":"AED","CZE":"CZK","CHN":"CNY"}

SUBS = [("6768126260","Yearly",0), ("6768126548","Monthly",1)]  # Streak Counter
SCHEDULED_START = (date.today() + timedelta(days=2)).isoformat()

def pick_price_point(client, sub_id, terr, target_usd):
    r = client.get(f"/subscriptions/{sub_id}/pricePoints?filter[territory]={terr}&limit=200")
    ccy = TERRITORY_CURRENCY.get(terr,"USD"); fx = FX.get(ccy,1.0)
    pts=[]
    for p in r["data"]:
        cp=float(p["attributes"]["customerPrice"]); pts.append((cp*fx, cp, p["id"]))
    pts.sort()
    eligible=[x for x in pts if x[0] <= target_usd]
    pick = eligible[-1] if eligible else pts[0]
    return pick[2], pick[1], pick[0]

def create_price(client, sub_id, terr_id, pp_id):
    body={"data":{"type":"subscriptionPrices",
        "attributes":{"preserveCurrentPrice":True,"startDate":SCHEDULED_START},
        "relationships":{
            "subscription":{"data":{"type":"subscriptions","id":sub_id}},
            "territory":{"data":{"type":"territories","id":terr_id}},
            "subscriptionPricePoint":{"data":{"type":"subscriptionPricePoints","id":pp_id}}}}}
    return client.post("/subscriptionPrices", body)

def main():
    kid,iss,kp=load_credentials(); client=ASCClient(bearer_token(kid,iss,kp))
    applied=0
    for sub_id,label,idx in SUBS:
        print(f"\n=== {label} ({sub_id}) — start {SCHEDULED_START} ===")
        for terr,targets in TIERS.items():
            tgt=targets[idx]
            try: pp_id,cp,usd=pick_price_point(client,sub_id,terr,tgt)
            except Exception as e: print(f"  {terr}: pp-fetch fail {str(e)[:80]}"); continue
            try:
                create_price(client,sub_id,terr,pp_id)
                print(f"  {terr}: -> {cp} {TERRITORY_CURRENCY.get(terr)} ~= ${usd:.2f} (<= ${tgt})"); applied+=1
            except Exception as e: print(f"  {terr}: post fail {str(e)[:120]}")
            time.sleep(0.2)
    print(f"\nApplied {applied} subscription price changes.")

if __name__=="__main__": main()
