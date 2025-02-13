# alb-log-exporter-lambda
AWS ALB Log Exporter

## Options
- Set the loggly token with the `LOGGLY_TOKEN` environment variable

## Useful commands
Generating a concatenated gzip file:
``` sh
gzip -c -n file1 > file.gz
gzip -c -n file2 >> file.gz
```
