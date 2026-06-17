window.BENCHMARK_DATA = {
  "lastUpdate": 1781719372694,
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
          "id": "bd2be688bf4a5e664a32a7541a35ab7af8fac823",
          "message": "finished and passed tests exercise 2",
          "timestamp": "2026-06-17T16:27:12Z",
          "tree_id": "9273c11142e5e2cda6617eddc303d78ccf7ed857",
          "url": "https://github.com/wuad391/jsip-exchange/commit/bd2be688bf4a5e664a32a7541a35ab7af8fac823"
        },
        "date": 1781713877771,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 393.1490506146331,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 2029.904854415188,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 3909.727822025508,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 19378.582657193725,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 103.30576375784837,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 456.7109944882849,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 892.026976515997,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 4260.5583550902375,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 230.67635435743193,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 1077.0039636184476,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 2194.3152817308387,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 10570.794597648232,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 1276.860427298676,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1680.3691540030857,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 7333.7147280517065,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 14568.177647178018,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 69145.44003958827,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 649.9349379863302,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 2849.9949909157885,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 5546.17575712131,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 26876.01130705962,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 7052.301983708352,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 128460.21589180871,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 527584.8989028214,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 3936.1799318288595,
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
          "id": "c4203ebfa4a96c1e387f8d26201fe60915924f79",
          "message": "exercise 3 done",
          "timestamp": "2026-06-17T17:28:19Z",
          "tree_id": "c0c8dd191f2308dc1d165c4db307c94b9efa5184",
          "url": "https://github.com/wuad391/jsip-exchange/commit/c4203ebfa4a96c1e387f8d26201fe60915924f79"
        },
        "date": 1781717567757,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 390.13780635132804,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 2061.566917357709,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 4001.269011844973,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 20221.454917214844,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 112.09838032248149,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 502.219508813002,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 985.3604611088344,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 4764.692445433272,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 242.21408889946608,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 1163.9994696474205,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 2213.464317970705,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 10917.961805819508,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 1572.1876124810212,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1772.116798363478,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 7600.246844891904,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 15308.489587527656,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 73100.81300153783,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 705.0990083143123,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 2981.26462000727,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 5718.573128461121,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 28395.27425320014,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 7297.715571719276,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 137026.8792930356,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 534515.3308687863,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 3897.673023039634,
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
          "id": "ca0481623663f3c5e946bf9eae8de5012431eda7",
          "message": "finished exercise 4",
          "timestamp": "2026-06-17T17:58:42Z",
          "tree_id": "40ae33598b06ce3bdedf91ebe0921d274d103d74",
          "url": "https://github.com/wuad391/jsip-exchange/commit/ca0481623663f3c5e946bf9eae8de5012431eda7"
        },
        "date": 1781719371829,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 420.30056479449786,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 2061.5838712400773,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 4237.919478918733,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 21113.658556400806,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 129.95948891135927,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 562.8987982220864,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 1111.017446574647,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 5483.354196982532,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 252.96088103021015,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 1122.8255118694165,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 2220.8102616780993,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 11222.568762343677,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 1629.7986839095718,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1868.0046130564588,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 8107.717922641584,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 16092.090990275352,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 76361.57543875495,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 716.0716457585869,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 2888.4699020803346,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 5798.192241831837,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 28355.064953892583,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 7642.31427665102,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 133180.2722007422,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 540259.9925045542,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 4126.028713587915,
            "unit": "ns"
          }
        ]
      }
    ]
  }
}