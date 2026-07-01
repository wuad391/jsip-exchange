window.BENCHMARK_DATA = {
  "lastUpdate": 1782918373644,
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
      },
      {
        "commit": {
          "author": {
            "email": "64043453+wuad391@users.noreply.github.com",
            "name": "wuad391",
            "username": "wuad391"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "f318f90dc6f6562644798ab38a56bdcf145f658e",
          "message": "Merge branch 'jane-street-immersion-program:main' into main",
          "timestamp": "2026-06-17T15:24:29-04:00",
          "tree_id": "c84808fd0b86af0f45cf677b866d7de632679f52",
          "url": "https://github.com/wuad391/jsip-exchange/commit/f318f90dc6f6562644798ab38a56bdcf145f658e"
        },
        "date": 1781724494503,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 307.4534038549107,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 1534.297539222899,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 2996.465640709466,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 14568.669651476735,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 83.71782850099073,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 378.9030765009444,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 734.5736412104144,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 3584.732903652305,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 196.20678573008738,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 1039.953809712427,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 2007.429346878519,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 9701.959291364932,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 1909.9627646117633,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1634.7844865730215,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 6782.367848135515,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 13134.880134362986,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 63587.83207716743,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 566.7756628685266,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 2860.752750649927,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 5243.151179208161,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 23632.134280865383,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 6820.586566356616,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 122938.94913811138,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 465481.7527004064,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 3012.5442580659146,
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
          "id": "9e0fcd9499451612798152a07a0a85cab9badaf3",
          "message": "EOD 6/17",
          "timestamp": "2026-06-17T20:52:11Z",
          "tree_id": "466530cdf11de6f032fff6aab691845c839b25c3",
          "url": "https://github.com/wuad391/jsip-exchange/commit/9e0fcd9499451612798152a07a0a85cab9badaf3"
        },
        "date": 1781729766259,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 373.09021757820005,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 1976.3800438411351,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 3924.4746459085545,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 19480.491291438273,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 111.96729456312781,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 501.8872496696201,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 984.4139917101368,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 4771.304073442942,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 238.66149595374497,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 1058.5202350998425,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 2106.301432850622,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 10584.646183358935,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 1281.293946677527,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1663.7018405030874,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 7562.7707230059605,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 15039.234061504385,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 72100.52192596976,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 668.5481248602177,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 2992.267944432908,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 5410.355768144422,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 28767.913600117372,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 7234.633970462928,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 128650.7113691864,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 516313.56725558784,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 3958.95827674169,
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
          "id": "b5383aea54c811bd41e3a1bb5f0a207e3fa446b5",
          "message": "eod fr",
          "timestamp": "2026-06-17T21:00:45Z",
          "tree_id": "b86bff5ccceb7e6b9e64ac1f8e90d49c924cf8f2",
          "url": "https://github.com/wuad391/jsip-exchange/commit/b5383aea54c811bd41e3a1bb5f0a207e3fa446b5"
        },
        "date": 1781730330084,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 358.68974995094607,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 1871.2576294637734,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 3327.1440391729193,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 16310.896405440051,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 93.22989272499939,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 403.59149818209164,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 782.8366175517508,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 3736.1379284268633,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 199.58426041283192,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 1005.7830312150309,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 2012.89292587391,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 9528.248198122472,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 1349.71002146166,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1418.3665823568801,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 6047.884014794354,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 12001.554687810401,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 57921.86704112223,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 560.5178049892204,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 2451.962086234217,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 4683.53146284031,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 23323.388034283413,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 6309.638418390054,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 112612.99490062003,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 434574.11506463325,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 3352.0320027825337,
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
          "id": "08ac5dc7b19ecdeaebc170fcb12149791a07e812",
          "message": "exercise 8a and 8b build, but not proof of correctness",
          "timestamp": "2026-06-18T20:23:07Z",
          "tree_id": "ae85e17651568dea35640d7e00f94cb1c9485673",
          "url": "https://github.com/wuad391/jsip-exchange/commit/08ac5dc7b19ecdeaebc170fcb12149791a07e812"
        },
        "date": 1781814392647,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 407.9243001057347,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 2102.3856858547947,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 4230.991597513746,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 19468.571592026943,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 112.50160951640751,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 500.9466430378706,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 1067.592005625591,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 5189.9263146101775,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 281.63803183053153,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 1246.950631039899,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 2469.614474857186,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 12257.964816603804,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 1703.5808662665515,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1880.0011755950006,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 7966.987426874964,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 15747.539080438268,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 76264.49733110069,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 727.8793039211483,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 3177.7044994954917,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 6219.776694926925,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 30682.169548789312,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 7905.974167499829,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 139158.17299571168,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 545802.1060533721,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 4349.504891411046,
            "unit": "ns"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "64043453+wuad391@users.noreply.github.com",
            "name": "wuad391",
            "username": "wuad391"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "984294ef81b0445d332aa7abc8730c548e672af8",
          "message": "Merge branch 'jane-street-immersion-program:main' into main",
          "timestamp": "2026-06-22T09:15:58-04:00",
          "tree_id": "c28d97f9dc789debbe16930b5e70db12dd82c7a3",
          "url": "https://github.com/wuad391/jsip-exchange/commit/984294ef81b0445d332aa7abc8730c548e672af8"
        },
        "date": 1782134410525,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 415.8355947125156,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 2012.877849855154,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 3932.818359272934,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 21767.69567947474,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 118.57413906551533,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 545.0922498524463,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 1074.3237579547733,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 5309.777626581657,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 258.23315145849654,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 1213.0480723565397,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 2261.1478252940606,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 10945.235197947293,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 1618.6002447412422,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1878.2981319875348,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 8297.337359331363,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 16234.969385069926,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 80213.89279228808,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 746.4786011084983,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 2912.4306737083116,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 5784.767175517074,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 28247.62401847868,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 8273.556534602661,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 146431.04082884695,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 577508.4523483154,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 4497.720242999043,
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
          "id": "f1a71b8c4f420341f980f17a63251229aee99645",
          "message": "exercise 10 is done and passes test. working through exercise 8 tests",
          "timestamp": "2026-06-22T16:03:03Z",
          "tree_id": "11de4956be08c02bc9dfe4c3f64c71e197d4e29f",
          "url": "https://github.com/wuad391/jsip-exchange/commit/f1a71b8c4f420341f980f17a63251229aee99645"
        },
        "date": 1782144432003,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 22.316935261447014,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 23.735497043419628,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 24.46863896525626,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 27.003782958707408,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 22.26757368149672,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 23.52910750972523,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 24.174803973407684,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 27.17045411726771,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 185.18121885988106,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 813.9760131478287,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 1588.5630098435342,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 7913.990157017229,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 245.9964572928263,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1192.978859664375,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 3918.4485978601215,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 7144.85983904671,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 33864.93313953768,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 473.6349549797718,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 1783.4840474882124,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 3298.927069674783,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 16013.566503856948,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 5797.734296686844,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 64628.883862006136,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 216279.49243886204,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 24.21275113533145,
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
          "id": "40b5330df4a4d25ec31e9fe5fd9e29093f6f1682",
          "message": "finished exercise 8",
          "timestamp": "2026-06-22T18:33:45Z",
          "tree_id": "c004b07b2a654ecdef139c3ad61b76927c82e9bb",
          "url": "https://github.com/wuad391/jsip-exchange/commit/40b5330df4a4d25ec31e9fe5fd9e29093f6f1682"
        },
        "date": 1782153411814,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 16.850403077869235,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 19.227891918625797,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 19.70756428647825,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 20.301438917861223,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 18.464893377700687,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 18.69559078185672,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 18.9743631829027,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 20.58381960645552,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 157.24086372675916,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 716.1235574777287,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 1352.0129020756704,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 7045.321690925728,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 213.92694583466886,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1005.7201535321385,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 3363.770164965802,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 6042.327304214605,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 29179.095952791064,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 431.53899987086936,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 1561.6555131392893,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 2891.2137828728173,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 14320.013737825835,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 4792.690883329309,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 56132.363305630905,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 184360.3628118953,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 19.530625003813135,
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
          "id": "6ce6e3827676a1c426a718f82d2e2c1a8de9691a",
          "message": "EOD: working on 1b. one type error line 110 on exchange_server",
          "timestamp": "2026-06-22T21:16:06Z",
          "tree_id": "770d9054d6ca9fbc8c267f5abc31a6979cc635a7",
          "url": "https://github.com/wuad391/jsip-exchange/commit/6ce6e3827676a1c426a718f82d2e2c1a8de9691a"
        },
        "date": 1782163207292,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 22.314911159057946,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 23.61328083857717,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 24.214515060469218,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 27.17303772568859,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 22.388154634416914,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 23.78284380043502,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 24.175412769115866,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 28.111616951001114,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 185.8759886444483,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 815.5186861042091,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 1606.9304262979235,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 7972.331330284277,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 267.6887077906651,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1206.2107257176344,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 4077.460290650617,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 7136.549292216384,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 35075.580436976925,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 488.415189199293,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 1835.9956797665743,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 3399.9801407630257,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 16697.633017750497,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 5904.332080796424,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 67175.14099069731,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 222773.3353653048,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 24.23424718436868,
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
          "id": "8703960cceafbb656481994ebaa00b17c263ae5f",
          "message": "compiled up to 1b. unsure of correctness as no orders are being processed",
          "timestamp": "2026-06-23T20:21:42Z",
          "tree_id": "e534271dec4356177706ffdce26ef5048ab49e8a",
          "url": "https://github.com/wuad391/jsip-exchange/commit/8703960cceafbb656481994ebaa00b17c263ae5f"
        },
        "date": 1782246341871,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 23.91684017632746,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 24.803141994892602,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 25.4506254581947,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 28.56426381848169,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 23.511367174211202,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 24.74473522382507,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 25.638625954937016,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 28.627916832573078,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 173.16620544983735,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 777.3967570962689,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 1547.9893562003508,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 7427.200257113376,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 260.35916924378466,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1169.3535719616525,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 3799.8575834328153,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 6733.497580822941,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 32233.23384756034,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 445.0919426805024,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 1680.4886536223448,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 3170.0341788792466,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 15443.801290402147,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 5864.181027684294,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 64568.340694674174,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 205623.25179524577,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 25.418845952340636,
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
          "id": "cbc5522e0f2651a28de2ca65a44c58af4ef5ba20",
          "message": "EOD. working on using the fill.to_participant_view for task 1c",
          "timestamp": "2026-06-23T21:06:33Z",
          "tree_id": "c61ddd6fbce0f7ceadd6754c1705397b6be6c495",
          "url": "https://github.com/wuad391/jsip-exchange/commit/cbc5522e0f2651a28de2ca65a44c58af4ef5ba20"
        },
        "date": 1782249000775,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 24.61786038416613,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 23.438815564774067,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 23.974353069739198,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 26.986345473370335,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 21.99916627762072,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 24.538248974669848,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 23.881240032284733,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 26.977066008608006,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 176.5495103913792,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 767.9825901528557,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 1586.1755203557966,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 7442.5909414555335,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 264.2421291226163,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1167.2440475372014,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 3767.772747158831,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 6965.570679723408,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 31212.14690625757,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 446.32086418364077,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 1676.0351146141243,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 3108.867122331375,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 15103.73278830255,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 5737.737079383601,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 63260.33928542154,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 205028.01678979766,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 23.90516493164518,
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
          "id": "4dc4b122f921d8246c620af8a93f7ababb137fe7",
          "message": "starting to work 1d",
          "timestamp": "2026-06-24T16:33:51Z",
          "tree_id": "686e0259d1b41b6b761e93bd998c4fcc93a09246",
          "url": "https://github.com/wuad391/jsip-exchange/commit/4dc4b122f921d8246c620af8a93f7ababb137fe7"
        },
        "date": 1782319123384,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 22.022197684463716,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 23.333497433570756,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 23.88210524015279,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 26.851010550642858,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 21.920610605978613,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 23.184485079661727,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 23.82492903812106,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 26.82202979563977,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 179.7524956420927,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 825.2164352267811,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 1532.296332938728,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 7534.632499698202,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 245.75540422195562,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1182.5078464108656,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 3751.7129395016955,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 6812.211196213921,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 31516.814855946297,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 472.9616543988062,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 1678.907596524044,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 3313.5193396721234,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 16248.076094099479,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 5898.89657878413,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 64709.38821884251,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 214168.9340815326,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 23.897735098470793,
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
          "id": "fa85c8e2dc11fa74f9a339bbafba36272c1e4f12",
          "message": "finished 1d. One small issue on test_end_to_end with the Audit messages coming in before the participant messages. Will need to check on this later",
          "timestamp": "2026-06-24T17:31:11Z",
          "tree_id": "02d7d045361bd80dbb9543eda7377142941e1062",
          "url": "https://github.com/wuad391/jsip-exchange/commit/fa85c8e2dc11fa74f9a339bbafba36272c1e4f12"
        },
        "date": 1782322582308,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 27.562992422938844,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 28.73809010368198,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 27.95832293348643,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 30.32160520841089,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 26.882412610727776,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 28.081190187317304,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 28.5112733979544,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 29.768405729916886,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 216.58291701566378,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 915.3781112869984,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 1780.587982733968,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 9034.431129785582,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 272.07696110735634,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1287.0431130520856,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 4530.990497559571,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 7620.54842320106,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 33996.53559923016,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 501.4032032637917,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 1867.6981694350904,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 3609.6574225533423,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 17918.720259566824,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 6373.865923101925,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 70052.9309452527,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 224460.7097527484,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 28.329729297439467,
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
          "id": "c5e51af69d1adea655351058f03207bd67165802",
          "message": "finished 1d. One small issue on test_end_to_end with the Audit messages coming in before the participant messages. Will need to check on this later",
          "timestamp": "2026-06-24T17:46:49Z",
          "tree_id": "02d7d045361bd80dbb9543eda7377142941e1062",
          "url": "https://github.com/wuad391/jsip-exchange/commit/c5e51af69d1adea655351058f03207bd67165802"
        },
        "date": 1782323485187,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 22.02176120260569,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 23.356874886208907,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 24.811304504398844,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 27.840964049078224,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 22.864994904089773,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 24.14772646424844,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 24.930338165579585,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 27.86735566359608,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 186.13593617334496,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 822.7096655760878,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 1610.0960796309669,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 7821.394637851976,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 257.1681788008815,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1239.6292811950802,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 3921.18913763722,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 7141.441278074109,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 33351.72988014644,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 466.4367878820405,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 1717.825004168863,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 3314.981223289936,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 16711.235895550766,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 5832.155751445783,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 65856.3161857349,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 222278.6403040559,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 23.9342652156863,
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
          "id": "b170ef24ac727d4fda220c5d2d6cdbb193e52b24",
          "message": "finished 1f, detecting duplicate client_order_ids",
          "timestamp": "2026-06-24T18:17:32Z",
          "tree_id": "54d9c8c8230ac7207d496bbde4a340d3fd7a8a37",
          "url": "https://github.com/wuad391/jsip-exchange/commit/b170ef24ac727d4fda220c5d2d6cdbb193e52b24"
        },
        "date": 1782325284122,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 22.01640641004665,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 23.246537375516777,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 23.87402584699286,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 26.92534105719897,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 21.954895933272464,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 23.438879934992663,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 23.86970589310244,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 26.854814890550205,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 189.3591389768647,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 826.1028006194896,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 1516.9002795030474,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 7539.947998715751,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 258.1900691727615,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1231.7898036177955,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 3954.5806013323568,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 7184.774187817333,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 33490.1537197477,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 494.2484250241424,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 1758.7799455797674,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 3330.328754052982,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 16227.521315986047,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 5924.329698543161,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 65941.00539965788,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 215066.31113787455,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 24.79664991073141,
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
          "id": "b80cb3d01014eabcd9b3fc7842ea2a3a27f3a7e7",
          "message": "finished 1d and 1e",
          "timestamp": "2026-06-25T14:42:13Z",
          "tree_id": "e7cb26537efbd731623174c90e08b6e328ecde1e",
          "url": "https://github.com/wuad391/jsip-exchange/commit/b80cb3d01014eabcd9b3fc7842ea2a3a27f3a7e7"
        },
        "date": 1782398769681,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 27.247324421601668,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 28.254592448257082,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 27.67829520289671,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 29.048895104581064,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 26.3983999140116,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 27.40265763492259,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 28.302649133482248,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 31.654622585844617,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 197.18033750952577,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 823.3269417004351,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 1569.271901960705,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 8058.053343521535,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 279.4705623064553,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 200162.54555618262,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 201581.44538009146,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 202148.60537288658,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 214904.98619058356,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 127450.3239832915,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 128143.60025242138,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 130418.19396076784,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 135643.0901563318,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 10007.687815458272,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 99828.39284158699,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 323954.5987315634,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 28.571978901555056,
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
          "id": "da753ee9e23622c6683d29022b81fb0f6bd63c66",
          "message": "passes all tests for ex 1. need to add more test",
          "timestamp": "2026-06-25T18:01:04Z",
          "tree_id": "b5c1ce67a94614189b96b059ee9098919d893920",
          "url": "https://github.com/wuad391/jsip-exchange/commit/da753ee9e23622c6683d29022b81fb0f6bd63c66"
        },
        "date": 1782410763569,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 22.800440902038172,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 23.679222594556723,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 24.637094228475693,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 27.400467131879584,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 23.044551549889558,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 24.07745426140711,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 24.790708432784392,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 27.549492837901642,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 185.05858455756055,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 846.7361469056394,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 1604.0093409198373,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 8457.943560751484,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 265.99264835961515,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 3580.872313363764,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 5620.49895404228,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 8756.012621058771,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 33871.38567152138,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 1289.8398825336553,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 2542.938056735133,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 3967.1730371174576,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 17071.187195693965,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 8148.127914426252,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 76695.00188931463,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 236811.36076835345,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 24.356813490322303,
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
          "id": "9816ec99c81b497ec013cf63a43a69605218170d",
          "message": "fixed session_feed bug and find_exn bug. all tests except double login and bbo update are working but not promoted",
          "timestamp": "2026-06-26T14:38:53Z",
          "tree_id": "9687c0de19ef48596f57555db0b52a4b0b9a5b12",
          "url": "https://github.com/wuad391/jsip-exchange/commit/9816ec99c81b497ec013cf63a43a69605218170d"
        },
        "date": 1782485008535,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 16.09832311070994,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 18.42993967779789,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 18.14860041691246,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 20.848919566170323,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 16.19843970742962,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 18.55334718794148,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 18.12813398683262,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 20.022266159184518,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 157.7488442544954,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 717.0092147033376,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 1358.159231382853,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 7025.577033121556,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 210.76832445994862,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1434.8871053332948,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 3834.7595627569117,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 6572.90425218876,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 29756.264579427156,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 584.4277635571148,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 1718.584990372292,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 3040.2917592326785,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 14385.211487861932,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 8327.30394436853,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 71908.85555848526,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 217476.79964754015,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 18.14552271612736,
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
          "id": "2b41a14c919be45e71f23f109ad31a371ee1c746",
          "message": "EXERCISE 1 IS FINALLY DONE",
          "timestamp": "2026-06-26T15:47:25Z",
          "tree_id": "52949937096a9976975e340ba9af8e53fc75e53f",
          "url": "https://github.com/wuad391/jsip-exchange/commit/2b41a14c919be45e71f23f109ad31a371ee1c746"
        },
        "date": 1782489126218,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 20.5911429803864,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 21.002473363705747,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 21.23585175392202,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 23.59722474267606,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 20.00749159304354,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 21.11734535960488,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 21.685058659367154,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 24.307617681198558,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 155.04472876002887,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 675.4090646860908,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 1315.765149798198,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 6258.149435370756,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 203.92813496701325,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1257.4694522280313,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 3509.5700437935247,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 6075.776127105573,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 26877.599163815055,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 496.3599546594829,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 1485.8605270528415,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 2811.7759307221095,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 13834.850614534185,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 7637.513369260271,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 65800.48437297327,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 196412.61960841226,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 22.466270166578962,
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
          "id": "089b37df5b6e8a8e56afa5153e7a08962e5b99b8",
          "message": "2a done but untested. 2b mostly done.",
          "timestamp": "2026-06-26T19:22:32Z",
          "tree_id": "0f4a295b9fca05622d98d764411a58c25239bc69",
          "url": "https://github.com/wuad391/jsip-exchange/commit/089b37df5b6e8a8e56afa5153e7a08962e5b99b8"
        },
        "date": 1782502002692,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 22.014254314448067,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 23.42936084816434,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 24.1663165838092,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 26.979976844603346,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 22.289543686801856,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 23.545565920062295,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 23.99841763273453,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 26.907290305850886,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 175.58824664984937,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 769.7131851952743,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 1498.4960367357673,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 7437.552863837329,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 250.15673774758218,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1676.5493998927266,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 4351.748280706078,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 7288.376009856738,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 33082.146378967846,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 670.6845283905196,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 1911.371063045142,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 3462.2807392572654,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 15483.458850520406,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 9386.297573430129,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 79705.77663652369,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 243320.95384467463,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 24.154323205880623,
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
          "id": "cd9a4acab0240783a99c92f5196aae043040edfc",
          "message": "compiles up to pre exercise 3. Basic tests run on ex. 2. waiting to get help on expect tests",
          "timestamp": "2026-06-29T18:37:35Z",
          "tree_id": "61083db0b49820da90665f0f8d660ac9dabef381",
          "url": "https://github.com/wuad391/jsip-exchange/commit/cd9a4acab0240783a99c92f5196aae043040edfc"
        },
        "date": 1782758498428,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 22.332748060951275,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 23.550547206469,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 23.98948331186899,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 27.157225077913818,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 22.275843317356955,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 23.203210246209903,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 23.886680440809666,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 27.122494428209343,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 175.82635810196874,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 766.9124026397799,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 1496.4656976953745,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 7495.9905318966785,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 255.59382393168238,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1682.169134290092,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 4589.196623588885,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 7665.1498975558015,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 32290.05713375637,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 650.1870882894991,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 1923.8216853517793,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 3493.475341142945,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 16108.557467788987,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 9554.950026949396,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 83712.18623871602,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 244775.77232970993,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 24.197388374859106,
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
          "id": "04910522a09378ccb2809f9d4d3f5eaf0b570acb",
          "message": "need to maybe add setter functions for MM state and fix red",
          "timestamp": "2026-06-29T21:19:04Z",
          "tree_id": "11736325c2217a715518de84b2d5c33624470e9c",
          "url": "https://github.com/wuad391/jsip-exchange/commit/04910522a09378ccb2809f9d4d3f5eaf0b570acb"
        },
        "date": 1782768229280,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 22.617003405067685,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 23.847385951022698,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 24.53722220101674,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 27.530110331024087,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 22.90041156809998,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 24.008986403455367,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 24.466887570105577,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 27.252174323873245,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 184.82332515761206,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 814.2101418782191,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 1590.0490198471907,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 8125.727141266221,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 256.4359400870696,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1705.1919204263602,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 4629.0708319365895,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 7374.390128518677,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 33394.32332145244,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 651.2879305316042,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 1939.1886469004487,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 3556.8783357868506,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 16502.380479746735,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 9588.92955516229,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 83532.84747979695,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 253545.8122655616,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 24.630571363948313,
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
          "id": "f932a827a15ba7e49346417caefc5cb9b7156b91",
          "message": "almost done with compilation for exercise 3. starting work on tests since blocked by question",
          "timestamp": "2026-06-30T13:54:42Z",
          "tree_id": "27061b504594e4e9a2306375e71868c17e507580",
          "url": "https://github.com/wuad391/jsip-exchange/commit/f932a827a15ba7e49346417caefc5cb9b7156b91"
        },
        "date": 1782827952234,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 27.233412197637687,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 28.64308108724146,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 29.01758759486223,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 31.468960695837367,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 26.864894300675118,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 28.432820254063557,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 28.968728304330174,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 32.22220513295321,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 193.93116697896568,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 837.9750950748204,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 1655.2111252389345,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 8572.260031963631,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 276.6826861793098,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1668.838487565138,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 4623.156819117997,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 8197.340991774376,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 34867.026255306206,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 681.0833083286104,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 2076.0334969087094,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 3831.9216355124095,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 18309.46525767704,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 9757.43859668573,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 84425.1551100611,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 264300.58831549005,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 28.891868949278685,
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
          "id": "6fb6918ed93ec1dbb7009d7e22f8b33073f04c8a",
          "message": "at least ex 3 compiles",
          "timestamp": "2026-06-30T15:56:40Z",
          "tree_id": "fbe6ff92613f154c08b97eff15d1115143429e33",
          "url": "https://github.com/wuad391/jsip-exchange/commit/6fb6918ed93ec1dbb7009d7e22f8b33073f04c8a"
        },
        "date": 1782835235736,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 28.289342349967022,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 27.185377881213654,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 26.912907721982723,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 30.125796058337876,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 25.802676474261393,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 26.26479865311462,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 27.20455459088632,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 30.13472265042736,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 207.32836231352331,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 803.8592143861259,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 1647.3583662974304,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 8454.617215179953,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 270.57418893425654,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1634.025738719823,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 4405.533731367554,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 7799.384066766908,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 35546.49303336037,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 639.1408506973856,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 1969.6498889539569,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 3607.3072014833633,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 17222.612883213653,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 9587.271840614469,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 81290.25491604256,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 253761.6600123602,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 28.233549351052396,
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
          "id": "3a93520a9d6c5455e6ced1f92d05d33f8a8d2f68",
          "message": "tests are happy for exercise 3",
          "timestamp": "2026-06-30T19:35:05Z",
          "tree_id": "c5fb4b5ede1e8d45729b08f5f0af9d4fca90e33b",
          "url": "https://github.com/wuad391/jsip-exchange/commit/3a93520a9d6c5455e6ced1f92d05d33f8a8d2f68"
        },
        "date": 1782848335373,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 26.37298555925613,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 27.403264532836538,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 27.6630537037715,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 31.887955636266323,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 27.628758893464216,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 29.192139074977472,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 28.64042500616292,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 31.95920003434601,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 206.83787845096668,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 895.0198918906952,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 1767.1535219873276,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 8037.874618300606,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 262.7190635305512,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1676.8647809997278,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 4480.290935151996,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 7822.36338811409,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 35696.490801250344,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 648.3047661279426,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 2166.5377952075437,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 3890.857037246687,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 18352.19797979263,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 9853.622342885164,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 83071.04145425622,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 264784.53909542365,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 28.669506480887765,
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
          "id": "11225fce2fe67cbec82149de705eaf83b6a46543",
          "message": "left off on on_tick for noise trader",
          "timestamp": "2026-06-30T20:46:59Z",
          "tree_id": "b20aef168c7f0e519a481fea570aa2e96c70ed05",
          "url": "https://github.com/wuad391/jsip-exchange/commit/11225fce2fe67cbec82149de705eaf83b6a46543"
        },
        "date": 1782852656991,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 28.56238330956833,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 29.71627573101312,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 30.59796814865829,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 32.54033281496818,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 24.323190990549126,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 27.218903206900237,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 27.91330878222512,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 31.185953947458046,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 197.0130025783683,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 854.5555028436808,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 1678.8134010422596,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 8231.003745809903,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 266.46445503023705,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1737.7335110473116,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 4845.988143918943,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 8640.603239260701,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 39426.16935092882,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 671.2421078442658,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 2045.4313344255695,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 4021.1590215613865,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 19115.928780102688,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 9709.798696609436,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 83647.87032592928,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 265111.20354880125,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 28.694951510681037,
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
          "id": "8deee845149dfb866cba048724a06d7388aa3198",
          "message": "fixed obvious bugs in market maker but still don't think it's working",
          "timestamp": "2026-07-01T13:54:20Z",
          "tree_id": "39c63bea2bca25def8cc8d44bfc738413ea3647e",
          "url": "https://github.com/wuad391/jsip-exchange/commit/8deee845149dfb866cba048724a06d7388aa3198"
        },
        "date": 1782914340697,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 22.150099132960428,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 23.672054064432,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 24.166519196482913,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 27.140081964979547,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 22.701252385170235,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 23.602599198157005,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 24.32345354777398,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 27.224870097874174,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 191.57557752722082,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 836.8402044141799,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 1645.2196979101443,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 7972.43571755917,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 256.3184600262905,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1697.0540846209028,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 4485.74199026477,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 7632.283795796105,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 33528.659049457165,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 677.0155681351326,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 1990.4040895999724,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 3655.4586502451752,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 16823.101580652965,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 9351.321456276728,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 80167.25867456956,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 248361.23675167904,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 24.109849670408874,
            "unit": "ns"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "64043453+wuad391@users.noreply.github.com",
            "name": "wuad391",
            "username": "wuad391"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "c6bf8408c2eb0792a633a4b03baea015dacf29d4",
          "message": "Merge branch 'jane-street-immersion-program:main' into main",
          "timestamp": "2026-07-01T11:02:53-04:00",
          "tree_id": "6906912b2482950193de2f2032f0c9f1438e9e30",
          "url": "https://github.com/wuad391/jsip-exchange/commit/c6bf8408c2eb0792a633a4b03baea015dacf29d4"
        },
        "date": 1782918373286,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 22.234746560371075,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 23.54034753408765,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 24.162021934914502,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 26.926778168595323,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 22.308848209575597,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 24.089931626795913,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 24.213660875507692,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 26.851064802843542,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 176.87305548877055,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 771.2979845558476,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 1586.7432750356866,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 7530.346132832695,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 257.4859345037302,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1668.0079986140295,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 4489.158450564044,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 7621.577863156757,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 33686.69011816407,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 665.0057341319497,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 1998.6830666635296,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 3597.1252950498692,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 15904.582505915598,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 9701.576424245875,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 80687.20968152441,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 244650.57570440456,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 25.054228227950638,
            "unit": "ns"
          }
        ]
      }
    ]
  }
}