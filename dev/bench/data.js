window.BENCHMARK_DATA = {
  "lastUpdate": 1781708976223,
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
      },
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
          "id": "7d9e166cf1031e3b86be5da923b70633da15d7dd",
          "message": "updated expect tests to be right format",
          "timestamp": "2026-06-17T15:05:02Z",
          "tree_id": "274c73bc2a1769dea2ee4bae185e72a3cb017310",
          "url": "https://github.com/wuad391/jsip-exchange/commit/7d9e166cf1031e3b86be5da923b70633da15d7dd"
        },
        "date": 1781708975674,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 120.31667226170748,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 531.9021933130939,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 1025.1103755720333,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 5007.094507017208,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 242.43109703506207,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 1210.0988478600398,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 2337.677269232534,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 11959.859777556241,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 241.40813403343006,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 1167.526053032119,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 2323.526467776363,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 11636.097466254752,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 1497.7177967939297,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 394263.6201727771,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 395537.98967391916,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 403464.3820560996,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 420239.4039280649,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 100.0808418104593,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 100.0359194366156,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 99.87362488742245,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 101.02713872011815,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 4209.957114359463,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 65320.35318267869,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 239788.3959234982,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 1048.905631075934,
            "unit": "ns"
          }
        ]
      }
    ]
  }
}