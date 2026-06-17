window.BENCHMARK_DATA = {
  "lastUpdate": 1781703556633,
  "repoUrl": "https://github.com/wuad391/jsip-exchange",
  "entries": {
    "Order book benchmark": [
      {
        "commit": {
          "author": {
            "email": "wuad391@gmail.com",
            "name": "Robyn",
            "username": "wuad391"
          },
          "committer": {
            "email": "wuad391@gmail.com",
            "name": "Robyn",
            "username": "wuad391"
          },
          "distinct": true,
          "id": "c1b02f41fbf2aae388bd47643b0d14b3b936932d",
          "message": "finished exercise 1 and step 1 of exercise 2. need to add more extensive tests, so no gurantee of correctness.",
          "timestamp": "2026-06-17T13:35:21Z",
          "tree_id": "9672e9287059374a8e3fa04ccee99120a55068b5",
          "url": "https://github.com/wuad391/jsip-exchange/commit/c1b02f41fbf2aae388bd47643b0d14b3b936932d"
        },
        "date": 1781703556349,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 95.93117516438981,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 419.82183715173,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 798.3692141397439,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 3791.2780758181416,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 192.59063306379775,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 958.3913040694173,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 1870.2167109744241,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 9173.519885405785,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 200.07151469604477,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 1055.6226129567792,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 2022.8751227977352,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 9754.334312894503,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 1974.6327320711741,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 359643.66746545845,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 363110.78692561947,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 361799.1374286883,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 376831.40988621995,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 75.37445685191146,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 75.09697521716603,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 74.63462375869204,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 75.34448126900092,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 3360.216064956143,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 54850.33840459494,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 207409.55374244374,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 793.9360087902994,
            "unit": "ns"
          }
        ]
      }
    ]
  }
}