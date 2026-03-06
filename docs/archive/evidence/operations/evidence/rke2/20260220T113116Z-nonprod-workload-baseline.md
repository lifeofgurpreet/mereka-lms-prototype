# RKE2 Nonprod Workload Baseline

- Timestamp (UTC): 20260220T113116Z
- Context: rke2-nonprod
- Namespace: mereka-lms

## Deployments
```
NAME                        DESIRED   READY    AVAILABLE
caddy                       1         1        1
cms                         1         1        1
cms-worker                  1         1        1
credentials                 1         1        1
discovery                   0         <none>   <none>
ecommerce                   0         <none>   <none>
ecommerce-worker            0         <none>   <none>
elasticsearch               1         1        1
elasticsearch-exporter      1         1        1
enterprise-access           1         1        1
enterprise-access-worker    1         1        1
enterprise-admin-portal     1         1        1
enterprise-catalog          1         1        1
enterprise-catalog-worker   1         1        1
enterprise-learner-portal   1         1        1
enterprise-subsidy          1         1        1
license-manager             1         1        1
lms                         1         1        1
lms-worker                  1         1        1
meilisearch                 1         1        1
mfe                         1         1        1
mongodb-exporter            1         1        1
mux-delivery-monitor        0         <none>   <none>
mysql                       1         1        1
mysql-exporter              1         1        1
notes                       0         <none>   <none>
payments-gateway            0         <none>   <none>
postgresql-payments         1         1        1
redis                       1         1        1
redis-exporter              1         1        1
smtp                        1         1        1
xqueue                      0         <none>   <none>
```

## Service Endpoints
```
NAME                        ENDPOINTS                                      AGE
caddy                       10.0.0.168:2019,10.0.0.168:443,10.0.0.168:80   3h32m
cms                         10.0.0.131:8000                                3h32m
credentials                 10.0.0.135:8000                                3h32m
discovery                   <none>                                         3h32m
ecommerce                   <none>                                         3h32m
elasticsearch               10.0.0.213:9200                                3h32m
elasticsearch-exporter      10.0.0.76:9114                                 3h32m
enterprise-access           10.0.0.156:18270                               3h32m
enterprise-admin-portal     10.0.0.63:8002                                 3h32m
enterprise-catalog          10.0.0.34:8160                                 3h32m
enterprise-learner-portal   10.0.0.49:8002                                 3h32m
enterprise-subsidy          10.0.0.57:18280                                3h32m
license-manager             10.0.0.178:18170                               3h32m
lms                         10.0.0.28:8000                                 3h32m
meilisearch                 10.0.0.165:7700                                3h32m
mfe                         10.0.0.242:8002                                3h32m
mongodb                     <none>                                         3h32m
mongodb-exporter            10.0.0.74:9216                                 3h32m
mux-delivery-monitor        <none>                                         3h32m
mysql                       10.0.0.10:9104,10.0.0.10:3306                  3h32m
mysql-exporter              10.0.0.176:9104                                3h32m
notes                       <none>                                         3h32m
payments-gateway            <none>                                         3h32m
postgresql-payments         10.0.0.41:5432                                 3h32m
promtail                    10.0.0.117:9080                                3h32m
redis                       10.0.0.71:6379,10.0.0.71:9121                  3h32m
redis-exporter              10.0.0.106:9121                                3h32m
smtp                        10.0.0.8:8025                                  3h32m
xqueue                      <none>                                         3h32m
```

## Core Route Smoke
```
200  https://academyv2.mereka.dev/
200  https://studio.academyv2.mereka.dev/
200  https://admin.academyv2.mereka.dev/
200  https://apps.academyv2.mereka.dev/authn/login
200  https://ecommerce.academyv2.mereka.dev/
500  https://credentials.academyv2.mereka.dev/
200  https://discovery.academyv2.mereka.dev/
200  https://notes.academyv2.mereka.dev/
200  https://preview.academyv2.mereka.dev/
```
