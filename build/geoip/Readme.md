# Sample data

File created with https://github.com/ipinfo/mmdbctl

CSV data:
```
ip,city,country,geoname_id,latitude,longitude,postalcode,region,timezone
8.8.8.8,Mountain View,US,5375480,37.4056,-122.0775,94043,California,America/Los_Angeles
```

Executed with:
```./mmdbctl_1.4.7_darwin_amd64 import --in sample.csv --out sample.mmdb```


-> ```curl -LO https://github.com/ipinfo/mmdbctl/releases/download/mmdbctl-1.4.7/mmdbctl_1.4.7_${PLAT}.tar.gz```
