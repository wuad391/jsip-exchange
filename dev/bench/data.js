window.BENCHMARK_DATA = {
  "lastUpdate": 1781814392931,
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
      }
    ]
  }
}