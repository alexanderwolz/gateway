# Sample data

File created with https://github.com/ipinfo/mmdbctl

The real GeoLite2-Country/City databases store `country`/`city` as nested
objects (e.g. `country.iso_code`, `country.names.en`, `city.names.en`), which
is exactly what `includes/geoip.conf` queries. A flat CSV import (e.g. one
column named `country`) produces a flat, non-nested record and silently
resolves to empty values at runtime -- so this sample is built from JSON
instead, which lets us express that nested shape directly.

geoip_sample.json:
```
{"range":"8.8.8.8/32","country":{"iso_code":"US","names":{"en":"United States"}},"city":{"names":{"en":"Mountain View"}}}
```

Executed with:
```./mmdbctl_1.4.7_darwin_amd64 import -i geoip_sample.json -o sample.mmdb --ip 4```


-> ```curl -LO https://github.com/ipinfo/mmdbctl/releases/download/mmdbctl-1.4.7/mmdbctl_1.4.7_${PLAT}.tar.gz```
