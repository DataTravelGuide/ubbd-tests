memleak=$1
downtime=$2

systemctl daemon-reload
systemctl restart ubbdd
